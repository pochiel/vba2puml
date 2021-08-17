all:
	bison vba2puml.y
	flex -d vba2puml.l
	gcc -O0 -g -o vba2puml lex.yy.c vba2puml.tab.c -lfl -ly -lm -DYYERROR_VERBOSE
clean:
	rm -f *.c *.h vba2puml
