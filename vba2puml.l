%{
#include "vba2puml.tab.h"
#include <string.h>
extern void push_synbol_string(char * smbl, int size);
extern void clear_synbol_string();
extern FILE * output_file_ptr;
int g_bracket_cnt = 0;

enum {
	C_UNRELATED_ELSE = 0,
	C_WITH_ELSE_SINGLE,
	C_WITH_ELSE_BLOCK,
};

void remove_char(char target, char converted_char, const char* in_str, int in_length, char* out_str, int *out_length){
	sprintf(out_str, "%s", in_str);
	for(int i=0;i<in_length;i++){
		if( out_str[i] == target ){
			out_str[i] = converted_char;
		}
	}
	*out_length = strlen(out_str);
}
void remove_line_feed(const char* in_str, int in_length, char* out_str, int *out_length){
	remove_char('\n', '\0', in_str, in_length, out_str, out_length);
	remove_char('\r', '\0', in_str, in_length, out_str, out_length);
}

int is_else_in_if = C_UNRELATED_ELSE;
#define process_if_block(__with_else)	({																\
								char buf[yyleng+1];														\
								int buf_leng = yyleng;													\
								remove_line_feed(yytext, yyleng, buf, &buf_leng);						\
								printf("if(s):        (%s) len=%d \n", buf, buf_leng);					\
								BEGIN(INITIAL); push_synbol_string(buf, buf_leng);						\
								is_else_in_if = __with_else;											\
								return(IF);																\
							})
							

#define process_elseif_block()	({																\
								char buf[yyleng+1];														\
								int buf_leng = yyleng;													\
								remove_line_feed(yytext, yyleng, buf, &buf_leng);						\
								printf("else if(s):        (%s) len=%d \n", buf, buf_leng);					\
								BEGIN(INITIAL); push_synbol_string(buf, buf_leng);						\
								return(ELSE_IF);																\
							})
enum {
	C_UNRELATED_WHILE = 0,
	C_WITH_BLOCK,
	C_WITHOUT_BLOCK,
};
int is_block_of_for = C_UNRELATED_WHILE;
#define process_for_block(__with_block)	({																\
								char buf[yyleng+1];														\
								int buf_leng = yyleng;													\
								remove_line_feed(yytext, yyleng, buf, &buf_leng);						\
								printf("for(s):        (%s) len=%d \n", buf, buf_leng);					\
								BEGIN(INITIAL); push_synbol_string(buf, buf_leng);						\
								is_block_of_for = __with_block;											\
								return(FOR);															\
							})

/* ブロック情報保持スタック */
typedef enum {
	C_BLOCK_TYPE_NONE = 0,
	C_BLOCK_TYPE_FUNCTION,
	C_BLOCK_TYPE_IF,
	C_BLOCK_TYPE_FOR,
	C_BLOCK_TYPE_WHILE,
	C_BLOCK_TYPE_ELSE,
	C_BLOCK_TYPE_WRONG = -10,
} t_blocktype;
#define MAX_OF_BLOCK_STACK	(128)



t_blocktype block_stack[MAX_OF_BLOCK_STACK] = {C_BLOCK_TYPE_NONE};
int block_stack_index = 0;

void push_block_stack(t_blocktype stc)	{
		printf("*************************** [push] blockstack[%d->%d]=%d\n", block_stack_index, block_stack_index+1, stc);
		block_stack[++	block_stack_index] = stc;
	}
t_blocktype pop_block_stack()	{
	printf("*************************** [pop] blockstack[%d->%d]=%d\n", block_stack_index, block_stack_index-1, block_stack[block_stack_index]);
	if(block_stack_index==0){ return C_BLOCK_TYPE_WRONG; }
	return block_stack[block_stack_index--];
	}

%}

white       [ \t\r\n]
floating    [0-9]+\.[0-9]+
integer     [0-9]+
symbol      [=+\-\^*/();\n]
letter      [_[:alpha:]][_[:alnum:]]*
other       .

%x STRING
%x CHARA
%x ST_COMMENT
%x ST_LINE_COMMENT
%x ST_IF_EXPR
%x ST_FOR_EXPR
%x ST_1LINE_FOR
%x ST_WHILE_EXPR
%x ST_ANY_OTHER

TYPE            String|Integer|Single|Double|Long
STO_CLASS       Public|Private
CONTROL         If|Else|For|While|Do|Goto
TYPE_QUAL       Const
C_KEYWORDS      {TYPE}|{STO_CLASS}|{CONTROL}|{TYPE_QUAL}

BOOL            Boolean|False|True
EXCEPTION       On Error GoTo

%%
{white}+
{STO_CLASS}*[ ]*"Function "{letter}+\(.*\)*.*(\r|\n)	{
													char buf[yyleng+1];
													int buf_leng = yyleng;
													remove_line_feed(yytext, yyleng, buf, &buf_leng);
													printf("start function:%s\n", yytext);
													push_synbol_string(buf, buf_leng);
													push_block_stack(C_BLOCK_TYPE_FUNCTION);
													return(FUNCTION);
											}
{STO_CLASS}*[ ]*"Sub "{letter}+\(.*\)*.*(\r|\n)	{
													char buf[yyleng+1];
													int buf_leng = yyleng;
													remove_line_feed(yytext, yyleng, buf, &buf_leng);
													printf("start sub:%s\n", yytext);
													push_synbol_string(buf, buf_leng);
													push_block_stack(C_BLOCK_TYPE_FUNCTION);
													return(FUNCTION);
											}
"End Function"				{	printf("function block closed");
								push_synbol_string("stop\n@enduml", sizeof("stop\n@enduml"));
								return(ENDFUNCTION);
							}
"End Sub"				{	printf("Sub block closed");
								push_synbol_string("stop\n@enduml", sizeof("stop\n@enduml"));
								return(ENDFUNCTION);
							}

"If ".+" Then"				{	printf("Start if block\n"); push_block_stack(C_BLOCK_TYPE_IF); process_if_block(C_WITH_ELSE_BLOCK); }
"End If"					{	pop_block_stack();
								printf("if block closed");
								return(ENDIF);
							}

"For ".+" To ".+			{	printf("for block\n"); push_block_stack(C_BLOCK_TYPE_FOR); process_for_block(C_WITH_BLOCK); }
Next					{	pop_block_stack();
									printf("for block closed");
									return(ENDWHILE);
						}

"While ".+				{	printf("while block\n"); push_block_stack(C_BLOCK_TYPE_WHILE); process_for_block(C_WITH_BLOCK); }
"Wend"					{	pop_block_stack();
									printf("while block closed");
									return(ENDWHILE);
						}

"Do "(While|Until)" ".+		{	printf("Do while block\n"); push_block_stack(C_BLOCK_TYPE_WHILE); process_for_block(C_WITH_BLOCK); }
"Loop"					{	pop_block_stack();
									printf("do while block closed");
									return(ENDWHILE);
						}

"'".*(\r|\n)            	{	char buf[yyleng+1];
								char buf2[yyleng+1];
								int buf_leng = yyleng;
								remove_line_feed(yytext, yyleng, buf, &buf_leng);
								remove_char('\'', ' ', buf, buf_leng, buf2, &buf_leng);
								printf("Comment(s):        (%s) len=%d\n", buf2, buf_leng);
								BEGIN(INITIAL);
								push_synbol_string(buf2, buf_leng);
								return(COMMENT); 
								}
<ST_LINE_COMMENT><<EOF>>		{	char buf[yyleng+1];
									int buf_leng = yyleng;
									remove_line_feed(yytext, yyleng, buf, &buf_leng);
									printf("Comment(s):        (%s) len=%d\n", buf, buf_leng);
									BEGIN(INITIAL);
									push_synbol_string(buf, buf_leng);
									return(COMMENT);
								}
<ST_LINE_COMMENT>[^*]+  		{	yymore(); }

"Else"					{ 	printf("start else block\n");
							pop_block_stack();
							push_block_stack(C_BLOCK_TYPE_ELSE);
							printf("else\n"); 
							push_synbol_string("else", sizeof("else"));
							return(ELSE); }

"ElseIf ".+" Then"				{	printf("Start else if block\n");
						pop_block_stack();
						push_block_stack(C_BLOCK_TYPE_ELSE);
						process_elseif_block();
						}

"Select Case ".+				{	printf("Start Select Case block\n"); push_block_stack(C_BLOCK_TYPE_IF); process_if_block(C_WITH_ELSE_BLOCK); }
"Case ".+					{	printf("Start Select Case in Case block\n");
							pop_block_stack();
							push_block_stack(C_BLOCK_TYPE_ELSE);
							process_elseif_block();
						}
"Case Else"					{ 	printf("Start Select Case in Case Else block\n");
							pop_block_stack();
							push_block_stack(C_BLOCK_TYPE_ELSE);
							push_synbol_string("else", sizeof("else"));
							return(ELSE); }
"End Select"					{	pop_block_stack();
							printf("Select block closed");
							return(ENDIF);
							}

.				{	BEGIN(ST_ANY_OTHER); yymore();	}
<ST_ANY_OTHER>(\r|\n)	{	char buf[yyleng+1];
							int buf_leng = yyleng;
							remove_line_feed(yytext, yyleng, buf, &buf_leng);
							printf("any other(s):        (%s) len=%d is_else_in_if=%d\n", buf, buf_leng, is_else_in_if);
							BEGIN(INITIAL); 
							push_synbol_string(buf, buf_leng); 
							if(is_block_of_for==C_WITHOUT_BLOCK) { is_block_of_for=C_UNRELATED_WHILE; return(ENDWHILE_SINGLE); }
							if(is_else_in_if==C_WITH_ELSE_SINGLE) { is_block_of_for=C_UNRELATED_WHILE; return(ENDIF_SINGLE); }
							return(ANY_OTHER); }
<ST_ANY_OTHER>. {	yymore(); }

<<EOF>>			{ printf("end of file\n"); return(END_OF_FILE); }

%%

#define C_OUTPUT_FILE_MAX    (256)
int main(int argc, char *argv[])
{
    FILE * fptr_r = NULL;
    FILE * fptr_w = NULL;
    int i;
    char opt;
    char output_filne_name[C_OUTPUT_FILE_MAX] = {0};
    char input_filne_name[C_OUTPUT_FILE_MAX] = {0};

    /* default name. */
    strncpy(output_filne_name, "out.puml", C_OUTPUT_FILE_MAX);

    for(i = 0; i < argc; ++i){
        if(*argv[i] == '-'){
            opt = *(argv[i]+1);
            switch(opt){
                case 'o':
                    strncpy(output_filne_name, argv[i+1], C_OUTPUT_FILE_MAX);
                    break;
                default:
                    printf("Undefined Option.\n");
                    break;
            }
            i++;
        } else {
            sprintf(input_filne_name, "./%s", argv[i]);
        }
    }
    /* Read file pointer */
    if ((fptr_r = fopen(input_filne_name, "r"))==NULL) {
        printf("file open failed.\n");
        exit(1);
    }
    
    /* write file pointer */
    if ((fptr_w = fopen(output_filne_name, "w"))==NULL) {
        printf("output file open failed.\n");
        exit(1);
    }

    /* 構文解析関数 yyparse */
    yyin = fptr_r;
    output_file_ptr = fptr_w;
    if( yyparse() != 0 ){
        printf("parse error.\n");
    }
    fclose(fptr_r);
    fclose(fptr_w);
    return 0;
}
