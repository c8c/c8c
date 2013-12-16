%option noyywrap yylineno 

%{
#include <stdlib.h>
#include "calc3.h"
#include "y.tab.h"
void yyerror(char *);
char text[500];

 
int yycolumn = 1;
#define YY_USER_ACTION yylloc.first_line = yylloc.last_line = yylineno;\
    yylloc.first_column = yycolumn; yylloc.last_column = yycolumn+yyleng-1;\
    yycolumn += yyleng;
%}

%x S

%%

0           {
                yylval.iValue = atoi(yytext);
                return INTEGER;
            }

[1-9][0-9]* {
                yylval.iValue = atoi(yytext);
                return INTEGER;
            }

[-()<>=+*/;{},.%] {
                return *yytext;
             }
\[|\]		{ return *yytext;}
"main"		return MAIN;
"-="		return ME;
"+="        return AE;		
"++"		return IN;
"--"		return DE;
">="            return GE;
"<="            return LE;
"=="            return EQ;
"!="            return NE;
"for"		return FOR;
"while"         return WHILE;
"if"            return IF;
"else"          return ELSE;
"print"         return PRINT;
"read"		return READ;
"&&"		return AND;
"||"		return OR;
"do"		return DO;
"continue"	return CONTINUE;
"break"		return BREAK;
"int"		return INT;
"char"		return CHAR;
"void"		return VOID;

\"		{ BEGIN S; *text = 0; }
<S>[^"\\]*	{ strcat(text, yytext); }
<S>\"		{ yylval.sIndex = strdup(text); BEGIN 0; return STRING; }
<S>\\\"		{ strcat(text, "\""); }
<S>\\n		{ strcat(text, "\n"); }
<S>\\t		{ strcat(text, "\t"); }
<S>\\		{ strcat(text, "\\"); }

'\\n'		{ yylval.iValue = (int) '\n'; return CHARACTER; }
'\\t'		{ yylval.iValue = (int) '\t'; return CHARACTER; }
'\\''		{ yylval.iValue = (int) '\''; return CHARACTER; }
''			{ yylval.iValue = 0; return CHARACTER; }
'[^']'		{ yylval.iValue = (int) yytext[1]; return CHARACTER; }
				
([a-zA-Z_])+([a-zA-Z0-9_])*      { 
                yylval.sIndex = strdup(yytext);
                return VARIABLE; 
}


\/\/.*\n	;	/* skip comments */

[ \t]+        ;       /* ignore whitespace */
\n		yycolumn = 1;
.               yyerror("Unknown character report in .l");
%%
