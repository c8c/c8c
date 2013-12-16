#include <stdio.h>
#include <stdlib.h>
#include "calc3.h"
#include "y.tab.h"
#include <string.h>

static int lbl;
static int lel;//label of exception
extern bool iserror;
extern char err[50];
extern char *errtext;

struct stack{
    int size;
    int i;
int (*data)[2];//data[0] for start lable, data[1] for end lable.
}s;
typedef struct funnode{
     int funid;
     int label;
     char *name;
     int returnType;
     nodeType * parameter;
     struct funnode * next;
 }FunNode;
 FunNode *fn = NULL;
 bool insertFunction(SymbolType type, nodeType* p, int funid);
 FunNode * getFunc(char * name);

typedef struct symbolnode{
    char * name;//Variable name
    SymbolType type;
    int index;//Variable offset in assembler, based on fp
    int dimension;
    int * size;//size of array size[0] -> size[dimension-1] from high dimension to low dimension
    int totalsize;//totalsize of this variable
    struct symbolnode * next;
} SymbolNode;

SymbolNode *sn = NULL;

bool insertSymbolDriver(SymbolType type, nodeType* p);
bool insertSymbol(char * name, SymbolType type, int dimension, int *size);
SymbolNode * getSymbol(char * name);
bool isDeclared(nodeType* p);
void storeOffsetInIn(nodeType* p);//store dynamical offset value of specified variable in 'in'
//void init();//reserve label for build in functions
void testOutofBoundary(nodeType* p);//test whether value of 'in' is larger than p->totalsize(out of index)
int getSymbolOffset(char * name, int dimension, int *size);
void push(int start, int end);
int top(int index);
int* pop();

int ex(nodeType *p) {
    int lblx, lbly, lbl1, lbl2, lblz, lbl3;
    int i,j;
    SymbolType type;
    int *size;
    if (!p) return 0;
    switch(p->type) {
        case typeCon:       
        printf("\tpush\t%d\n", p->con.value); 
        break;  
        case typeId:
        printf("\tpush\tfp[%d]\n",getSymbol(p->id.i)->index);
        break;
        case typeStr:
        printf("\tpush\t\"%s\"\n",p->str.value);// " not include in con.value
        break;
        case typeArr:
        storeOffsetInIn(p);
        testOutofBoundary(p);
        printf("\tpush\tfp[in]\n");
        break;
        case typeOpr:
            switch(p->opr.oper) {
                case INT: 
                case CHAR://Declaration
                    if(p->opr.oper == INT)
                        type = INTTYPE;
                    else if(p->opr.oper == CHAR)
                        type = CHARTYPE;
                    else{
                        printf("Compile Error(1072): Unknown indentifier type\n");
                        exit(-1);
                    }
                    switch(p->opr.op[0]->type){
                        case typeId://A variable
                            printf("\tpush\tsp\n");//allocate space in stack
                            printf("\tpush\t1\n");
                            printf("\tadd\t\n");
                            printf("\tpop\tsp\n");
                            break;
                        case typeArr://An array
                            size = (int *)malloc(sizeof(int) * p->opr.op[0]->arr.dimension);
                            for(i = 0; i < p->opr.op[0]->arr.dimension; i++){
                                ex(p->opr.op[0]->arr.index[i]);
                            }
                            for(i = 0; i < p->opr.op[0]->arr.dimension - 1; i++){
                                printf("\tmul\t\n");
                                }
                            printf("\tpush\tsp\n");
                            printf("\tadd\t\n");
                            printf("\tpop\tsp\n");
                            break;
                        default:
                            printf("Compile Error(1070): Unknown declaration type. <%d>\n",p->opr.op[0]->type);
                            exit(-1);
                            break;
                    }
                    break;
                case CODEBLOCK:
                    ex(p->opr.op[0]);
                    ex(p->opr.op[1]);
                    break;
                case FOR:
                    ex(p->opr.op[0]);
                    printf("L%03d:\n", lblx = lbl++);
                    ex(p->opr.op[1]);
                    printf("\tj0\tL%03d\n", lbly = lbl++);
                    lblz = lbl++;
                    push(lblz,lbly);        
                    ex(p->opr.op[3]);
                    printf("L%03d:\n", lblz);
                    ex(p->opr.op[2]);
                    printf("\tjmp\tL%03d\n", lblx);
                    printf("L%03d:\n", lbly);
                    pop();
                    break;
                case CALL:
                    char* fun_name = p->opr.op[0]->id.i;//get function name;
                    int numofparas = 0;
                    FunNode* func;
                    nodeType* paras;
                    /*push parameters in stack*/
                    for(paras = p->opr.op[1];paras != NULL;paras = paras->next){
                        storeOffsetInIn(paras->name);
                        if(paras->name->type == typeArr)
                            testOutofBoundary(paras->name);
                        printf("\tpush\tfp[in]\n");//push para in stack
                        numofparas++;
                    }
                    /*actually, this exist check should be done in c8.y*/
                    if(func = getFunc(fun_name) == NULL){ 
                        printf("Error 1051: function (%s())not declared.\n",fun_name);
                        exit(-1);
                    }
                    printf("\tcall\tL%03d,%d\n",func->label,numofparas);
                break;
                case WHILE:
                    printf("L%03d:\n", lbl1 = lbl++);
                    ex(p->opr.op[0]);
                    printf("\tj0\tL%03d\n", lbl2 = lbl++);
                    push(lbl1,lbl2);
                    ex(p->opr.op[1]);
                    printf("\tjmp\tL%03d\n", lbl1);
                    printf("L%03d:\n", lbl2);
                    pop();
                break;
                case DO-WHILE:
                    lbl1 = lbl++;
                    lbl2 = lbl++;
                    lbl3 = lbl++;
                    push(lbl3,lbl2);
                    printf("L%03d:\n",lbl1);
                    ex(p->opr.op[0]);
                    printf("L%03d:\n", lbl3);
                    ex(p->opr.op[1]);
                    printf("\tj0\tL%03d\n", lbl2);
                    printf("\tjmp\tL%03d\n", lbl1);
                    printf("L%03d:\n", lbl2);
                    pop();
                break;
                case BREAK: printf("\tjmp\tL%03d\n", top(1)); break;
                case CONTINUE: printf("\tjmp\tL%03d\n", top(0)); break;
                case IF:
                ex(p->opr.op[0]);
                if (p->opr.nops > 2) {
                    printf("\tj0\tL%03d\n", lbl1 = lbl++);
                    ex(p->opr.op[1]);
                    printf("\tjmp\tL%03d\n", lbl2 = lbl++);
                    printf("L%03d:\n", lbl1);
                    ex(p->opr.op[2]);
                    printf("L%03d:\n", lbl2);
                } else {
                    printf("\tj0\tL%03d\n", lbl1 = lbl++);
                    ex(p->opr.op[1]);
                    printf("L%03d:\n", lbl1);
                }
                break;
                case READ:
                    printf("\tgeti\n");
                    storeOffsetInIn(p->opr.op[0]); 
                    if(p->opr.op[0]->type == typeArr)
                        testOutofBoundary(p->opr.op[0]);               
                    printf("\tpop\tfp[in]\n");
                break;
                case PRINT:     
                    ex(p->opr.op[0]);
                    printf("\tputi\n");
                break;
                case '=':
                    ex(p->opr.op[1]);
                    storeOffsetInIn(p->opr.op[0]);
                    if(p->opr.op[0]->type == typeArr)
                        testOutofBoundary(p->opr.op[0]);
                    printf("\tpop\tfp[in]\n");
                break;
                case UMINUS:    
                    ex(p->opr.op[0]);
                    printf("\tneg\n");
                break;
            default:/*Expr*/
/*semicolon*/
        ex(p->opr.op[0]);
        ex(p->opr.op[1]);
        switch(p->opr.oper) {
            case '+':   printf("\tadd\n"); break;
            case '-':   printf("\tsub\n"); break; 
            case '*':   printf("\tmul\n"); break;
            case '/':   printf("\tdiv\n"); break;
            case '%':   printf("\tmod\n"); break;
            case '<':   printf("\tcomplt\n"); break;
            case '>':   printf("\tcompgt\n"); break;
            case GE:    printf("\tcompge\n"); break;
            case LE:    printf("\tcomple\n"); break;
            case NE:    printf("\tcompne\n"); break;
            case EQ:    printf("\tcompeq\n"); break;
            case AND:   printf("\tand\n"); break;
            case OR:    printf("\tor\n"); break;
        }
    }
}
return 0;
}
void storeOffsetInIn(nodeType* p){
        int offset;//Calculate varaible offset to fp
        int i,j;
        printf("\tpush\t0\n");
        printf("\tpop\tin\n");//in = 0
        switch(p->type){
            case typeId:
            offset = getSymbol(p->id.i)->index;
            break;
            case typeArr:
            offset = getSymbol(p->arr.id)->index;
            for(i = 0; i < p->arr.dimension;i++){
                ex(p->arr.index[i]);
                for(j = i + 1; j < p->arr.dimension; j++){
                    printf("\tpush\t%d\n",getSymbol(p->arr.id)->size[j]);
                    printf("\tmul\t\n");
                }
                printf("\tpush\tin\n");
                printf("\tadd\t\n");
                printf("\tpop\tin\n");
            }
            break;
            default:
            printf("Compile Error(1072): Unknown type\n");
            break;
        }
        printf("\tpush\t%d\n",offset);
        printf("\tpush\tin\n");
        printf("\tadd\n");
        printf("\tpop\tin\n");
    }
    void setEmpty(){
        if (s.data)
        {
            free(s.data);
            s.data = NULL;
            s.size = 0;
            s.i = -1;
        }
    }
    void push(int start, int end){
    if(!s.data){//Didn't creat
        s.data = (int (*)[2])malloc(sizeof(int [2]) * 100);
    s.i = -1;
    s.size = 100;   
}
    else if(s.i == s.size - 1){//Full, double the size
        int (*new_data)[2] = (int (*)[2])malloc(sizeof(int [2]) * s.size * 2);
        memcpy(new_data,s.data,sizeof(int [2]) * s.size);
        free(s.data);
        s.data = new_data;
        s.size = s.size * 2;
        //s.i remains unchange
    }
    s.i++;
    s.data[s.i][0] = start;
    s.data[s.i][1] = end;
}
int top(int index){
    if(index != 0 && index != 1){
        printf("Compile Error(0001):\n");
        exit(-1);
    }
    return s.data[s.i][index];
}
int * pop(void){
    if(s.i == -1){
        printf("Compile Error(1060): stack is empty!\n");
        exit(-1);   
    }
    return s.data[s.i--];
}
/*Maintain Symbol Table*/
bool insertSymbolDriver(SymbolType type, nodeType* p){
    int i;
    int *size;
    if(!p) return false;
    switch(p->type){
                    case typeId://A variable
                    size = (int *)malloc(sizeof(int));
                    *size = 1;
                        return insertSymbol(p->id.i,type,1,size);//name type dimesion size
                        break;
                    case typeArr://An array
                    size = (int *)malloc(sizeof(int) * p->arr.dimension);
                    int tempsize;
                    for(i = 0;i < p->arr.dimension; i++){
                        tempsize = inter(p->arr.index[i]);
                        if(tempsize > 0)
                            size[i] = tempsize;
                        else{
                            strcat(err,"Error: size of array is zero or negative"); errtext = p->arr.id;
                            return false;
                        }                        
                    }
                        return insertSymbol(p->arr.id, type, p->arr.dimension, size);//last parameter: size
                        break;
                    }
                }
                bool insertSymbol(char * name, SymbolType type, int dimension, int *size){
                    SymbolNode * p, *lastNode;
                    int lastIndex = 0;
                    int i = 0;
                    int j = 0;
                    if(sn==NULL){
                        if(!(sn = (SymbolNode *)malloc(sizeof(SymbolNode)))){
                            strcat(err,"Error: Can not allocate memory for symbol "); errtext = name; 
                            return false;
                        }
                        sn->index = 0;
    sn->name = name;//Name has already been allocated enough space in bison
    sn->dimension = dimension;
        sn->size = size;//* Size has already been allocated enough space in ex() 
        sn->totalsize = 0;  
        for(i = 0; i < dimension ; i++){
            int thissize = size[i];
            for(j = i+1; j < dimension ; j++)
                thissize *= size[j];
            sn->totalsize += thissize;
        }
        sn->type = type;
        sn->next = NULL;
    }
    else{
        for(p = sn; p != NULL;p = p->next){
            if (!strcmp(p->name,name))//Same symbol name
            {
                strcat(err,"Error: Variable redeclared"); errtext = name; 
                return false;
            }
            lastIndex += p->totalsize;
            lastNode = p;
        }
        if(!(lastNode->next = (SymbolNode *)malloc(sizeof(SymbolNode)))){
            strcat(err,"Error: Can not allocate memory for symbol "); errtext = name; 
            return false;
        }
        /*Move pointer to last node*/
        lastNode = lastNode->next;
        /*Copy infomation*/
        lastNode->name = name;
        lastNode->dimension = dimension;
        lastNode->size = size;
        lastNode->totalsize = 0;
        for(i = 0; i < dimension ; i++){
            int thissize = size[i];
            for(j = i+1; j < dimension ; j++)
                thissize *= size[j];
            lastNode->totalsize += thissize;
        }
        lastNode->type = type;
        lastNode->index = lastIndex;
        lastNode->next = NULL;
    }
    return true;    
}
bool isDeclared(nodeType* p){
    switch(p->type){
        case typeId:
        if(getSymbol(p->id.i) == NULL)//symbol not exist
            return false;
        else
            return true;
        break;
        case typeArr:
        if(getSymbol(p->arr.id) == NULL)//symbol not exist
            return false;
        else
            return true;
        break;
    }
}
SymbolNode * getSymbol(char * name){
    SymbolNode * p;    
    for(p = sn; p != NULL;p = p->next){
        if (!strcmp(p->name,name))//Same symbol name
        {
            return p;
        }
    }
    return NULL;
    //exit(-1);
}
bool insertFunction(SymbolType type, nodeType* p, int funid){
     FunNode * pTmp, *lastNode;
     if(!p) return false;
     if(!fn){
     if(!(fn = (FunNode *)malloc(sizeof(FunNode)))){
         strcat(err,"Error: Can not allocate memory for function "); errtext = p->fun.name; 
         return false;
     }
     fn->funid = funid;
     fn->name = p->fun.name;
     fn->returnType = p->fun.returnType;
     fn->parameter = p->fun.paraHead;
     fn->label = lbl++;
     fn->next = NULL;
         }
     else{
      for(pTmp = fn; pTmp != NULL;pTmp = pTmp->next){
             if (!strcmp(pTmp->name, p->fun.name))//Same symbol name
             {
                 strcat(err,"Error: Function redeclared"); errtext =  p->fun.name; 
             return false;
             }
             lastNode = pTmp;
        }
      if(!(lastNode->next = (FunNode *)malloc(sizeof(FunNode)))){
         strcat(err,"Error: Can not allocate memory for function "); errtext =  p->fun.name; 
         return false;
         }
         /*Move pointer to last node*/
         lastNode = lastNode->next;
         /*Copy infomation*/
         lastNode->name = p->fun.name;
         lastNode->funid = funid;
         lastNode->returnType = p->fun.returnType;
     lastNode->parameter = p->fun.paraHead;
     lastNode->label = lbl++;
     lastNode->next = NULL;
     }
     return true;
     
 }
 FunNode * getFunc(char * name){
     
     FunNode * p;    
     for(p = fn; p != NULL;p = p->next){
         if (!strcmp(p->name,name))
         {
             return p;
         }
     }
     return NULL;
     //exit(-1);
 }
/**
 * Test whether the index of array is out of boundary.
 */
 void testOutofBoundary(nodeType* p){
    int lbx;
    SymbolNode * symbol;
    switch(p->type){
        case typeId:
        symbol = getSymbol(p->id.i);
        break;
        case typeArr:
        symbol = getSymbol(p->arr.id);
        break;
        default:
        printf("Compile Error(1071): Unknown type.\n");
        exit(-1);
        break;
    }
    printf("\tpush\tin\n");
    printf("\tpush\t%d\n",symbol->totalsize + symbol->index);
    printf("\tcomplt\n");// 1 if in < upperbound
    printf("\tpush\tin\n");    
    printf("\tpush\t%d\n",symbol->index);
    printf("\tcompge\n"); // 1 if in >= lowerbound
    printf("\tand\n");//if (in < upperbound && in >= lowerbound) jump
    printf("\tj1\tL%03d\n",lbx = lbl++);
    printf("\tpush\t\"Runtime Error(100): Index out of boundary.\"\n");
    printf("\tcall\tL%03d,1\n", lel);
    printf("\tend\n");
    printf("L%03d:\n", lbx);
}
void c8c_init(){
    lel = lbl++;//label for runtime error exception
}
/**
 * Setup inbuild function for exception handler
 * It should be executed for one time at the end of main function
 */
 void setupInbuildFunc(){   
    printf("\tend\n");//end main function.
    /*RuntimeException(char * msg)*/
    printf("L%03d:\n",lel);
    printf("\tpush\tfp[-4]\n");
    printf("\tputs\n");
    printf("\tret\n");
    /*to be continued*/
}
/**
 * Interprete Expression
 */
 int inter(nodeType *p) {
    if (!p) {printf("Compile Error(1010): Unknown Type\n");exit(-1);return 0;}
    switch(p->type) {
        case typeCon:       return p->con.value;
        case typeOpr:
        switch(p->opr.oper) {
            case UMINUS:    return -inter(p->opr.op[0]);
            case '+':       return inter(p->opr.op[0]) + inter(p->opr.op[1]);
            case '-':       return inter(p->opr.op[0]) - inter(p->opr.op[1]);
            case '*':       return inter(p->opr.op[0]) * inter(p->opr.op[1]);
            case '/':       return inter(p->opr.op[0]) / inter(p->opr.op[1]);
            case '%':       return inter(p->opr.op[0]) % inter(p->opr.op[1]);
            case '<':       return inter(p->opr.op[0]) < inter(p->opr.op[1]);
            case '>':       return inter(p->opr.op[0]) > inter(p->opr.op[1]);
            case GE:        return inter(p->opr.op[0]) >= inter(p->opr.op[1]);
            case LE:        return inter(p->opr.op[0]) <= inter(p->opr.op[1]);
            case NE:        return inter(p->opr.op[0]) != inter(p->opr.op[1]);
            case EQ:        return inter(p->opr.op[0]) == inter(p->opr.op[1]);
            case AND:   return inter(p->opr.op[0]) && inter(p->opr.op[1]);
            case OR:    return inter(p->opr.op[0]) || inter(p->opr.op[1]);
        }
    }
    return 0;
}