/* Ocamlyacc parser for Grid compiler */

%{
open Ast

let first (a,_,_) = a;;
let second (_,b,_) = b;;
let third (_,_,c) = c;;
%}


%token SEMI LPAREN RPAREN LBRACE RBRACE COMMA LARRAY RARRAY
%token PLUS MINUS TIMES DIVIDE INARROW OUTARROW ASSIGN NOT DOT PERCENT DEREF REF MODULO
%token EQ NEQ LT LEQ GT GEQ TRUE FALSE AND OR GRIDINIT GRID NULL
%token RETURN IF ELSE FOR WHILE INT BOOL VOID STRING PLAYER PIECE
%token <int> LITERAL
%token <string> ID
%token <string> STRING_LIT
%token EOF

%nonassoc NOASSIGN
%nonassoc NOELSE
%nonassoc ELSE
%nonassoc NOLARRAY
%nonassoc POINTER
%right ASSIGN
%right INARROW
%right OUTARROW
%left OR
%left AND
%left EQ NEQ
%left LT GT LEQ GEQ
%left PLUS MINUS MODULO
%left TIMES DIVIDE
%right NOT NEG DEREF REF
%left DOT

%start program
%type <Ast.program> program

%%

program:
  decls EOF { $1 }

decls:
   /* nothing */ { [], [], [] } 
 | decls vdecl { (List.append $2 (first $1)), second $1, third $1 }
 | decls fdecl { first $1, ($2 :: second $1), third $1 }
 | decls sdecl { first $1, second $1, ($2 :: third $1) }

fdecl:
   typ ID LPAREN formals_opt RPAREN LBRACE vdecl_list stmt_list RBRACE
     { { typ = $1;
   fname = $2;
   formals = $4;
   locals = List.rev $7;
   body = List.rev $8 } }

formals_opt:
    /* nothing */ { [] }
  | formal_list   { List.rev $1 }

formal_list:
    typ ID                   { [($1,$2)] }
  | formal_list COMMA typ ID { ($3,$4) :: $1 }

typ:
    INT { Int }
  | BOOL { Bool }
  | VOID { Void }
  | STRING { String }
  | array1d_type { $1 }   /* int[4] */
  | array2d_type { $1 }   /* int[4][3] */
  | PIECE ID { StructType ($2) } 
  | PLAYER { PlayerType }
  | typ TIMES %prec POINTER { PointerType ($1) }  
  | GRIDINIT LT LITERAL COMMA LITERAL GT { GridType ($3, $5) }

array1d_type:
    typ LARRAY LITERAL RARRAY %prec NOLARRAY { Array1DType($1,$3) }  /* int[4] */

array2d_type:
    typ LARRAY LITERAL COMMA LITERAL RARRAY { Array2DType($1,$3,$5) } /* int[4][3] */

arr_literal:
  expr   {[$1]} 
  | arr_literal COMMA expr {$3::$1}

vdecl_list:
    /* nothing */    { [] }
  | vdecl_list vdecl { List.append $2 $1 }

multi_vdecl:
     ID {[$1]}
   | multi_vdecl COMMA ID {$3::$1}

vdecl:
   typ multi_vdecl SEMI { List.map (fun x -> ($1,x)) $2 }

sdecl:
    PIECE ID LBRACE vdecl_list fdecl RBRACE
      { { sname = $2; 
      sformals = $4;
      sfunc = $5;
      } }
    | PLAYER LBRACE vdecl_list fdecl RBRACE
      { { sname = "Player"; 
      sformals = $3;
      sfunc = $4;
      } }

stmt_list:
    /* nothing */  { [] }
  | stmt_list stmt { $2 :: $1 }

stmt:
    expr SEMI { Expr $1 }
  | RETURN SEMI { Return Noexpr }
  | RETURN expr SEMI { Return $2 }
  | LBRACE stmt_list RBRACE { Block(List.rev $2) }
  | IF LPAREN expr RPAREN stmt %prec NOELSE { If($3, $5, Block([])) }
  | IF LPAREN expr RPAREN stmt ELSE stmt    { If($3, $5, $7) }
  | FOR LPAREN expr_opt SEMI expr SEMI expr_opt RPAREN stmt
     { For($3, $5, $7, $9) }
  | WHILE LPAREN expr RPAREN stmt { While($3, $5) }

expr_opt:
    /* nothing */ { Noexpr }
  | expr          { $1 }

expr:
    LITERAL          { Literal($1) }
  | NULL             { Null("GenericPiece") }
  | TRUE             { BoolLit(true) }
  | FALSE            { BoolLit(false) }
  | GRID LT expr COMMA expr GT INARROW expr { GridAssign($3,$5,$8) }
  | GRID LT expr COMMA expr GT OUTARROW expr { DeletePiece($3,$5,$8) }
  | expr ASSIGN expr { Assign($1,$3) }
  | ID               { Id($1) }
  | STRING_LIT        { String_Lit($1) }
  | ID LARRAY expr COMMA expr RARRAY ASSIGN expr { Array2DAssign($1,$3,$5,$8)}
  | ID LARRAY expr RARRAY ASSIGN expr { Array1DAssign($1, $3, $6) }
  | ID LARRAY expr COMMA expr RARRAY %prec NOASSIGN { Array2DAccess ($1,$3,$5) }
  | ID LARRAY expr RARRAY %prec NOLARRAY{Array1DAccess($1,$3)}
  | expr PLUS   expr { Binop($1, Add,   $3) }
  | expr MINUS  expr { Binop($1, Sub,   $3) }
  | expr TIMES  expr { Binop($1, Mult,  $3) }
  | expr DIVIDE expr { Binop($1, Div,   $3) }
  | expr EQ     expr { Binop($1, Equal, $3) }
  | expr NEQ    expr { Binop($1, Neq,   $3) }
  | expr LT     expr { Binop($1, Less,  $3) }
  | expr LEQ    expr { Binop($1, Leq,   $3) }
  | expr GT     expr { Binop($1, Greater, $3) }
  | expr GEQ    expr { Binop($1, Geq,   $3) }
  | expr AND    expr { Binop($1, And,   $3) }
  | expr OR     expr { Binop($1, Or,    $3) }
  | expr MODULO expr { Binop($1, Modulo, $3) }
  | expr DOT    ID   { Dotop($1, $3) }
  | MINUS expr %prec NEG { Unop(Neg, $2) }
  | TIMES expr %prec DEREF { Unop(Deref, $2) }
  | REF expr { Unop(Ref, $2) }
  | NOT expr         { Unop(Not, $2) }
  | ID LPAREN actuals_opt RPAREN { Call($1, $3) }
  | LPAREN expr RPAREN { $2 }
  | LARRAY arr_literal RARRAY {ArrayLiteral(List.rev $2)}

actuals_opt:
    /* nothing */ { [] }
  | actuals_list  { List.rev $1 }

actuals_list:
    expr                    { [$1] }
  | actuals_list COMMA expr { $3 :: $1 }
