
%locations
%{
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include "calc3.h"

#define SIZEOF_NODETYPE ((char *)&p->con - (char *)p)
/* prototypes */
nodeType *newMem(nodeType *p);
nodeType *opr(int oper, int nops, ...);
nodeType *id(char *i);
nodeType *arr(char *id, int dimension, nodeType *lastIndex, nodeType **preIndex);
nodeType *con(int value);
nodeType *str(char *string);

nodeType *para(nodeType *prePara, int type, nodeType *identifier);
nodeType *fun(char *name, nodeType *stmt, int returnType, nodeType *para);

void freeNode(nodeType *p);
void c8c_init();
int ex(nodeType *p);
void setupInbuildFunc();
int yylex(void);

/**
 * lyyerror(char *)
 * yyerror(char *)
 * char err[50]
 */
extern char * yytext;
char * errtext;
bool iserror;
void lyyerror(char *);
void yyerror(char *s);
typedef struct {
   int first_line,first_column;
 } errlocation;
 errlocation lastErrLocation = {0,0};

nodeType *parseTree[1024];
int count=1;

void c8y_init();
char err[50] = "";

int sym[26];                    /* symbol table */
int funCount=0;
int thisFunc;
%}

%union {
    int iValue;                 /* integer value */
    char *sIndex;                /* symbol table index */
    nodeType *nPtr;             /* node pointer */
};

%token <iValue> INTEGER CHARACTER
%token <sIndex> VARIABLE STRING
%token FOR WHILE IF PRINT READ DO BREAK CONTINUE INT CHAR VOID MAIN FUNCTION CODEBLOCK CALL%nonassoc IFX
%nonassoc ELSE
%left AND OR

%left GE LE EQ NE AE ME '>' '<' 
%left '+' '-'
%left '*' '/' '%'
%nonassoc ARRAY
%nonassoc UMINUS DE IN

%type <nPtr> stmt expr stmt_list stmtInLoop stmtInLoop_list ident array parameter main function paras compound_stmt program error
%%

program:
                main
              | function program 
              ;
main:
                INT MAIN '(' parameter ')' '{' compound_stmt '}'         {  thisFunc = funCount++; $$ = fun("main", $7, INT, $4); 
									    if(!insertFunction(INTTYPE,$$)){$$ = NULL;iserror = true; 											 lyyerror(err); YYERROR;  } 
									    else parseTree[0] = $$;}
               | error MAIN          { $$ = NULL; iserror = true; 
                                               strcat(err,"Error: return type of main() must be 'int' ");
                                               lyyerror(err); err[0] = 0;YYERROR;
                                             }
               ;

function:
                INT VARIABLE '(' parameter ')' '{' compound_stmt '}'     
                                                          { $$ = id($2); $$ = fun($$->id.i, $7, INT, $4);  
								if(!insertFunction(INTTYPE,$$)){$$ = NULL;iserror = true; 											 lyyerror(err);   }
								else parseTree[count++] = $$; }
   |CHAR VARIABLE '(' parameter ')' '{'
   compound_stmt '}'         { $$ = id($2); $$ = fun($$->id.i, $7, CHAR, $4);  if(!insertFunction(INTTYPE,$$)){$$ = NULL;iserror = true; 											 lyyerror(err);   } 
								else parseTree[count++] = $$; }
   | error VARIABLE   { $$ = NULL; iserror = true; printf("Error: return type of %s() is illegal",$2);YYERROR;}
              ;

parameter:
   parameter ',' INT ident       { $$ = para($1, INT, $4); }
   | parameter ',' CHAR ident      { $$ = para($1, CHAR, $4); }
   | CHAR ident            { $$ = para(NULL, CHAR, $2); }
   | INT ident             { $$ = para(NULL, INT, $2); }
   | error ident                              {$$ = NULL;strcat(err,"Error: unknown type"); lyyerror(err); err[0] = 0;}
   | /*NULL*/              { $$ = NULL; /*$$ = para(NULL, 0, NULL); */}
   ;

paras:
	ident 								{ $$ = para(NULL, 0, $1); }
	| paras ',' ident 					{ $$ = para($1, 0, $3);}
	| /*NULL*/							{ $$ = NULL; /*$$ = para(NULL, 0, NULL);*/ }
	;

compound_stmt:
          compound_stmt stmt                 { $$ = opr(CODEBLOCK, 2, $1, $2); }
   | /*NULL*/              {$$ = NULL;}
   ;

stmt:
          ';'                       { $$ = opr(';', 2, NULL, NULL); }
        | expr ';'                  { $$ = $1; }
        | PRINT expr ';'            { $$ = opr(PRINT, 1, $2); }
  | READ ident ';'      { if(isDeclared($2)) $$ = opr(READ, 1, $2);
                 else {$$ = NULL; iserror = true;
              printf("Variable undeclared: \"%s\" at line %d, cols %d-%d\n",
                        GETSYMBOLNAME($2), @1.first_line, @1.first_column, @1.last_column);
                    }
            }
        | ident '=' expr ';'        { if(isDeclared($1)) $$ = opr('=', 2, $1, $3);
                 else {$$ = NULL; iserror = true;
              printf("Variable undeclared: \"%s\" at line %d, cols %d-%d\n",
                        GETSYMBOLNAME($1), @1.first_line, @1.first_column, @1.last_column);
                    }
            } 
  | FOR '(' stmt stmt stmt ')' stmtInLoop { $$ = opr(FOR, 4, $3, $4,$5, $7); }
        | WHILE '(' expr ')' stmtInLoop     { $$ = opr(WHILE, 2, $3, $5); }
  | IF '(' expr ')' stmt %prec IFX  { $$ = opr(IF, 2, $3, $5);}
  | IF '(' expr ')' stmt ELSE stmt  { $$ = opr(IF, 3, $3, $5, $7);}
        | '{' stmt_list '}'               { $$ = $2; }
  | DO  stmtInLoop  WHILE '(' expr ')' ';'{ $$ = opr(DO-WHILE, 2, $2, $5); }
  | INT ident ';'       { if(insertSymbolDriver(INTTYPE,$2)) $$ = opr(INT, 1, $2);
                else {$$ = NULL;iserror = true; YYERROR;}
            }
        | CHAR ident ';'      { if(insertSymbolDriver(CHARTYPE,$2)) $$ = opr(CHAR, 1, $2);
                else {$$ = NULL;iserror = true; YYERROR;} 
                                                }
  | error ';'       { $$ = NULL;
                                                  iserror = true;
              if(!errtext)
                                                      errtext = $1;
                                                  if (err[0]) {
                        lyyerror(err);
                        err[0] = 0;
                    }
                    else lyyerror("Unexpected ");
            }

  ;
stmt_list:
          stmt                      { $$ = $1; }
        | stmt_list stmt            { $$ = opr(';', 2, $1, $2); }
  ;
stmtInLoop:                                       /*These statements can be in the loop*/
    ';'                           { $$ = opr(';', 2, NULL, NULL); }
  | expr ';'                      { $$ = $1; }
        | PRINT expr ';'                  { $$ = opr(PRINT, 1, $2); }
  | READ ident ';'      { if(isDeclared($2)) $$ = opr(READ, 1, $2);
                 else {$$ = NULL; iserror = true;
              printf("Variable undeclared: \"%s\" at line %d, cols %d-%d\n",
                        GETSYMBOLNAME($2), @1.first_line, @1.first_column, @1.last_column);
                    }

             }
        | ident '=' expr ';'            { if(isDeclared($1)) $$ = opr('=', 2, $1, $3);
                 else {$$ = NULL; iserror = true;
              printf("Variable undeclared: \"%s\" at line %d, cols %d-%d\n",
                        GETSYMBOLNAME($1), @1.first_line, @1.first_column, @1.last_column);
                    }
            } 
  | FOR '(' stmt stmt stmt ')' stmtInLoop { $$ = opr(FOR, 4, $3, $4,$5, $7); }
        | WHILE '(' expr ')' stmtInLoop     { $$ = opr(WHILE, 2, $3, $5); }
  | IF '(' expr ')' stmtInLoop %prec IFX  { $$ = opr(IF, 2, $3, $5);}
  | IF '(' expr ')' stmtInLoop ELSE stmtInLoop { $$ = opr(IF, 3, $3, $5, $7);}
        | '{' stmtInLoop_list '}'               { $$ = $2; }
  | DO  stmtInLoop WHILE '(' expr ')' ';' { $$ = opr(DO-WHILE, 2, $2, $5); }
 
  | BREAK ';'       { $$ = opr(BREAK, 0); }
  | CONTINUE ';'        { $$ = opr(CONTINUE, 0); }
        ;
stmtInLoop_list:
          stmtInLoop                        { $$ = $1; }
        | stmtInLoop_list stmtInLoop          { $$ = opr(';', 2, $1, $2); }
        ;
expr:
          INTEGER           { $$ = con($1); }
  | STRING          { $$ = str($1); }
  | CHARACTER         { $$ = con($1); }
        | ident           { if(isDeclared($1)) $$ = $1; 
                  else {$$ = NULL; iserror = true;
                printf("Variable undeclared: \"%s\" at line %d, cols %d-%d\n",
                        GETSYMBOLNAME($1), @1.first_line, @1.first_column, @1.last_column);
                      }
              }
  | DE ident          { $$ = opr('=', 2, newMem($2), opr('+', 2, $2, con(1)));}
  | IN ident          { $$ = opr('=', 2, newMem($2), opr('-', 2, $2, con(-1)));}
        | ident AE expr         { $$ = opr('=', 2, newMem($1), opr('+', 2, $1, $3)); }
  | ident ME expr         { $$ = opr('=', 2, newMem($1), opr('-', 2, $1, $3)); }
  | '-' expr %prec UMINUS         { $$ = opr(UMINUS, 1, $2); }
        | expr '+' expr                 { $$ = opr('+', 2, $1, $3); }
        | expr '-' expr                 { $$ = opr('-', 2, $1, $3); }
        | expr '*' expr                 { $$ = opr('*', 2, $1, $3); }
        | expr '%' expr                 { $$ = opr('%', 2, $1, $3); }
        | expr '/' expr                 { $$ = opr('/', 2, $1, $3); }
        | expr '<' expr                 { $$ = opr('<', 2, $1, $3); }
        | expr '>' expr                 { $$ = opr('>', 2, $1, $3); }
        | expr GE expr                  { $$ = opr(GE, 2, $1, $3); }
        | expr LE expr                  { $$ = opr(LE, 2, $1, $3); }
        | expr NE expr                  { $$ = opr(NE, 2, $1, $3); }
        | expr EQ expr                  { $$ = opr(EQ, 2, $1, $3); }
  | expr AND expr           { $$ = opr(AND, 2, $1, $3); }
  | expr OR expr            { $$ = opr(OR, 2, $1, $3); }
        | '(' expr ')'                  { $$ = $2; }
        | VARIABLE '(' paras ')'			{ $$ = opr(CALL, 2, $1, $3); }
        ;

ident:
      VARIABLE                    { $$ = id($1); }
    | array           { $$ = $1; }
    ;
array:
      VARIABLE '[' expr ']' %prec ARRAY   { $$ = arr($1, 1, $3, NULL); }
    | array '[' expr ']'        { $$ = arr($1->arr.id, ++$1->arr.dimension, $3, $1->arr.index); }
    ;

%%
nodeType *para(nodeType *prePara, int type, nodeType *identifier)
{
 nodeType *p, *pTmp; 
 size_t nodeSize;
 
 nodeSize = SIZEOF_NODETYPE + sizeof(paraNodeType);
 
    if ((p = malloc(nodeSize)) == NULL)
        yyerror("out of memory");
   
 if(!prePara){
   p->type = typePara;
   p->para.type = type;
   p->para.name = identifier;
   p->para.next = NULL;
   return p;
 }
 pTmp = prePara;
 while(pTmp->para.next){
   pTmp = pTmp->para.next;
 }
 p->type = typePara;
 p->para.type = type;
 p->para.name = identifier;
 p->para.next = NULL;
 pTmp->para.next = p;
 
 return prePara;
}

nodeType *fun(char *name, nodeType *stmt, int returnType, nodeType *para){
 nodeType *p; 
 size_t nodeSize;
 
 nodeSize = SIZEOF_NODETYPE + sizeof(funNodeType);
 
    if ((p = malloc(nodeSize)) == NULL)
        yyerror("out of memory");
   
 p->type = typeFun;
 p->fun.name = name;
 p->fun.stmt = stmt;
 p->fun.returnType = returnType;
 p->fun.paraHead = para;
 return p;
}

nodeType *arr(char *id, int dimension, nodeType *lastIndex, nodeType **preIndex)
{
  nodeType *p; 
  size_t nodeSize;
  int i=0;
  
  nodeSize = SIZEOF_NODETYPE + sizeof(arrNodeType) +
       (dimension - 1) * sizeof(nodeType*);
  
    if ((p = malloc(nodeSize)) == NULL)
        yyerror("out of memory");
    
  p->type = typeArr;
  p->arr.id = id;
  p->arr.dimension = dimension;
  
  if(preIndex != NULL)
  {
    for(i=0; i<dimension-1; i++)
      p->arr.index[i] = preIndex[i];
  }
  
  p->arr.index[i] = lastIndex;
  
  return p;
}

nodeType *str(char *string) {
  nodeType *p;
    size_t nodeSize;

    /* allocate node */
    nodeSize = SIZEOF_NODETYPE + sizeof(strNodeType);
    if ((p = malloc(nodeSize)) == NULL)
        yyerror("out of memory");

    /* copy information */
    p->type = typeStr;
    p->str.value = string;

    return p;
}

nodeType *con(int value) {
    nodeType *p;
    size_t nodeSize;

    /* allocate node */
    nodeSize = SIZEOF_NODETYPE + sizeof(conNodeType);
    if ((p = malloc(nodeSize)) == NULL)
        yyerror("out of memory");

    /* copy information */
    p->type = typeCon;
    p->con.value = value;

    return p;
}

nodeType *id(char *i) {
    nodeType *p;
    size_t nodeSize;

    /* allocate node */
    nodeSize = SIZEOF_NODETYPE + sizeof(idNodeType);
    if ((p = malloc(nodeSize)) == NULL)
        yyerror("out of memory");

    /* copy information */
    p->type = typeId;
    p->id.i = i;

    return p;
}

nodeType *opr(int oper, int nops, ...) {
    va_list ap;
    nodeType *p;
    size_t nodeSize;
    int i;

    /* allocate node */
    nodeSize = SIZEOF_NODETYPE + sizeof(oprNodeType) +
        (nops - 1) * sizeof(nodeType*);
    if ((p = malloc(nodeSize)) == NULL)
        yyerror("out of memory");

    /* copy information */
    p->type = typeOpr;
    p->opr.oper = oper;
    p->opr.nops = nops;
    va_start(ap, nops);
    for (i = 0; i < nops; i++)
        p->opr.op[i] = va_arg(ap, nodeType*);
    va_end(ap);
    return p;
}

nodeType *newMem(nodeType *p)
{
  nodeType *tmp;
  size_t nodeSize;
  nodeSize = SIZEOF_NODETYPE + sizeof(arrNodeType) +
       (p->arr.dimension - 1) * sizeof(nodeType*);
  
    if ((tmp = malloc(nodeSize)) == NULL)
        yyerror("out of memory");
  memcpy(tmp, p, nodeSize);
  return tmp;
}

void freeNode(nodeType *p) {
    int i;

    if (!p) return;
    if (p->type == typeOpr) {
        for (i = 0; i < p->opr.nops; i++)
            freeNode(p->opr.op[i]);
    }
    free (p);
}

/**
 * error recover
 */
void yyerror(char *s) {  
      if(yylloc.first_line == lastErrLocation.first_line && yylloc.first_column == lastErrLocation.first_column)
          return;
      fprintf(stdout,"%s at line %d, cols %d-%d\n",s,yylloc.first_line,yylloc.first_column,yylloc.last_column); 
  }
void lyyerror(char *s) {
   if(yylloc.first_line == lastErrLocation.first_line && yylloc.first_column == lastErrLocation.first_column)
       return;
  printf("%s: \"%s\" at line %d, cols %d-%d\n", s, errtext,
    yylloc.first_line, yylloc.first_column, yylloc.last_column);
  errtext = NULL;
  lastErrLocation.first_line = yylloc.first_line;
  lastErrLocation.first_column = yylloc.first_column;
}

/**
 *
 */
void c8y_init(){
    iserror = false;
}
int main(int argc, char **argv) {
extern FILE* yyin;
    int i;
    yyin = fopen(argv[1], "r");
    c8y_init();
    c8c_init();
    yyparse();
    if(iserror == false){
        for(i = 0; i < count; i++){
          ex(parseTree[i]);
        }
           setupInbuildFunc();
    }
    return 0;
}
