c8c: lex.yy.c y.tab.c c8c.c calc3.h
	gcc -o c8c lex.yy.c y.tab.c c8c.c
lex.yy.c: c8.l
	flex c8.l
y.tab.c: c8.y
	yacc -d c8.y

nas: nas.c nas.tab.c
	gcc -o nas nas.c nas.tab.c

nas.c: nas.l
	flex -o nas.c nas.l

nas.tab.c: nas.y
	bison -d nas.y

cleanc8c:
	$(RM) lex.yy.c y.tab.c y.tab.h

cleannas:
	$(RM) nas.c nas.tab.c
