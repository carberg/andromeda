%{
  open InputTT

%}


%token <bool> BOOL
%token <string> ANDROMEDATERM
%token <string> ANDROMEDATYPE
%token <int> INJ
%token <int> INT
%token <string> NAME
%token <string> STRING

%token ANDAND
%token ASCRIBE
%token ASSUME
%token BANG
%token BAR
%token COLON
%token COLONEQ
%token COMMA
%token CONTEXT
%token DARROW
%token DASH
%token DEBRUIJN
%token DEFINE
%token ELSE
%token END
%token EOF
%token EQ
%token EQEQ
%token EVAL
%token EXPLODE
%token FINALLY
%token FORALL
%token FUN
%token GETCTX
%token HANDLE
%token HANDLER
%token HELP
%token IF
%token IMPLODE
%token IN
%token LAMBDA
%token LBRACK
%token LET
%token LPAREN
%token LTGT
%token MATCH
%token NAMEOF
%token OP
%token PLUS
%token PLUSPLUS
%token QUIT
%token RBRACK
%token RPAREN
%token SEMISEMI
%token STAR
%token THEN
%token TYPEOF
%token UNDERSCORE
%token UNIT
%token VAL
%token WHEN
%token WHNF
%token WITH


%start <InputTT.toplevel list> file
%start <InputTT.toplevel> commandline

%type <InputTT.handler> hcases
%type <InputTT.handler> handler

(*%nonassoc ASCRIBE*)
(*%left ANDAND*)
(*%left PLUSPLUS*)
(*%left PLUS*)


%nonassoc EQEQ
%right INJ

%%

(* Toplevel syntax *)

file:
  | filecontents EOF            { $1 }

filecontents:
  |                                { [] }
  | topdef sso filecontents        { $1 :: $3 }
  | topdirective sso filecontents  { $1 :: $3 }
  (*| tophandler sso filecontents    { $1 :: $3 }*)

(*tophandler: mark_position(plain_tophandler) { $1 }*)
(*plain_tophandler:*)
  (*| WITH handler { TopHandler($2) }*)

commandline:
  | topdef SEMISEMI        { $1 }
  | topdirective SEMISEMI  { $1 }

(* Things that can be defined on toplevel. *)
topdef: mark_position(plain_topdef) { $1 }
plain_topdef:
  | LET NAME COLONEQ comp0                  { TopLet ($2, $4) }
  | LET NAME COLONEQ exp0                  { TopLet ($2, (Return $4, snd $4)) }
  | DEFINE ttname COLONEQ comp0               { TopDef ($2, $4) }
  | DEFINE ttname COLONEQ exp0               { TopDef ($2, (Return $4, snd $4)) }
  | EVAL comp0                              { TopEval $2 }
  | ASSUME nonempty_list(ttname) COLON comp0  { TopParam ($2, $4) }
  | ASSUME nonempty_list(ttname) COLON exp0  { TopParam ($2, (Return $4, snd $4)) }

(* Toplevel directive. *)
topdirective: mark_position(plain_topdirective) { $1 }
plain_topdirective:
  | CONTEXT    { Context }
  | HELP       { Help }
  | QUIT       { Quit }

sso :
  |          {}
  | SEMISEMI {}

(* Main syntax tree *)

(* Only know the end when we see it *)
exp0: mark_position(plain_exp0) { $1 }
plain_exp0:
    | FUN name DARROW comp0   { Fun ("_", $2, $4) }
    | FUN name LPAREN name RPAREN DARROW comp0   { Fun ($2, $4, $7) }
    | exp1 PLUS exp1 { Prim(Plus, [$1; $3]) }
    | exp1 DASH exp1 { Prim(Minus, [$1; $3]) }
    | exp1 STAR exp1 { Prim(Times, [$1; $3]) }
    | exp1 PLUSPLUS exp1 { Prim(Append, [$1; $3]) }
    | exp1 ANDAND exp1   { Prim(And, [$1; $3]) }
    | exp1 EQ exp1    { Prim(Eq, [$1; $3]) }
    | exp1 LTGT exp1   { Prim(Neq, [$1; $3]) }
    | plain_exp1              { $1 }


(* Has a clearly demarcated end token, known from the start *)
exp1: mark_position(plain_exp1) { $1 }
plain_exp1:
    | NAME                              { Var $1 }
    | handler                { Handler $1 }
    | LBRACK es=separated_list(COMMA, exp0) RBRACK    { Tuple es }
    | const                  { Const $1 }
    | INJ exp1               { Inj ($1, $2) }
    | LPAREN plain_exp0 RPAREN      { $2 }
    | BANG exp1         { Prim(Not, [$2]) }
    | WHNF exp1         { Prim(Whnf, [$2]) }
    | ANDROMEDATERM     { AndromedaTermCode $1 }
    | ANDROMEDATYPE     { AndromedaTypeCode $1 }
    | GETCTX            { Prim(GetCtx, []) }
    | EXPLODE exp1      { Prim(Explode, [$2]) }
    | IMPLODE exp1      { Prim(Implode, [$2]) }
    | NAMEOF exp1       { Prim(NameOf, [$2]) }
    | TYPEOF exp1       { Prim(TypeOf, [$2]) }

(* Only know the ending when we see it *)
comp0: mark_position(plain_comp0) { $1 }
plain_comp0:
    | VAL exp0        { Return $2 }

    | exp1 exp1        { App ($1, $2) }
    | exp1 ASCRIBE exp1        { Ascribe ($1, $3) }
    | OP NAME exp1    { Op ($2, $3) }
    | LET pat EQ comp0 IN comp0 { Let($2, $4, $6) }
    | LET FUN NAME LPAREN name RPAREN EQ comp0 IN comp0
        { let floc = Position.make $startpos($2) $endpos($8)  in
          let f = Fun($3, $5, $8), floc  in
          Let(PVar $3, (Return f, floc), $10)
        }
    | HANDLE comp0 WITH exp1  { WithHandle ($4, $2) }
    | WITH exp1 HANDLE comp0  { WithHandle ($2, $4) }
    | LAMBDA name COLON exp0 COMMA comp0 { MkLam($2, $4, $6) }
    | LAMBDA name COLON comp0 COMMA comp0
         { let loc = Position.make $startpos $endpos in
           Let(PVar "lambda annot", $4, mkMkLam ~loc $2 (mkVar "lambda annot") $6) }
    | IF exp0 THEN comp0 ELSE comp0
         {  Match($2, [PConst (Bool true), $4;
                       PConst (Bool false), $6]) }

    | MATCH e=exp0 WITH option(BAR) lst=separated_list(BAR, arm) END { Match (e, lst) }
    | DEBRUIJN INT       { MkVar $2 }
    | LPAREN plain_comp0 RPAREN { $2 }

arm:
  toppat DARROW comp0 { ($1, $3) }

pat0:
  | NAME { PVar $1 }
  | UNDERSCORE { PWild }

pat:
    | LBRACK xs=separated_list(COMMA, pat) RBRACK { PTuple xs }
    | INJ pat  { PInj($1, $2) }
    | NAME      { PVar $1 }
    | const     { PConst $1 }
    | UNDERSCORE { PWild }
    | pat EQEQ pat  { PJuEqual ($1, $3) }
    | FORALL pat COMMA pat0 { PProd ($2, $4) }
    | FORALL pat COLON pat COMMA pat COLON pat0 { PProdFull ($2, $4, $6, $8) }
    | LPAREN pat RPAREN { $2 }

toppat:
    | pat  { $1 }
    | pat WHEN exp1 { PWhen($1, $3) }
    | LPAREN pat WHEN exp1 RPAREN { PWhen($2,$4) }

handler:
    | HANDLER hcs=hcases END { hcs }

hcases:
    |              { { valH = None; opH = []; finH = None; } }
    | option(BAR) OP op=NAME p=toppat k=NAME DARROW c=comp0 hcs=hcases { { hcs with opH = (op,p,k,c)::hcs.opH }  }
    | option(BAR) VAL     xv=NAME DARROW cv=comp0 hcs=hcases { { hcs with
    valH=Some (xv,cv) } }
    | option(BAR) FINALLY xf=NAME DARROW cf=comp0 hcs=hcases { { hcs with finH=Some (xf,cf) } }

const:
    | INT  { Int $1 }
    | BOOL { Bool $1 }
    | UNIT { Unit }
    | STRING { String $1 }

name:
    | NAME       { $1 }
    | UNDERSCORE { "_" }

ttname:
    | NAME { $1 }
    | INT  { string_of_int $1 }

mark_position(X):
  x = X
  { x, Position.make $startpos $endpos }

%%
