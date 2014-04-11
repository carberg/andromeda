(** Annotated abstract syntax for Brazilian type theory. *)

type name = string

(** We use de Bruijn indices *)
type variable = Common.debruijn

type universe = Universe.t * Position.t

type ty = ty' * Position.t
and ty' =
  | Universe of universe
  | El of universe * term
  | Unit
  | Prod of name * ty * ty
  | Paths of ty * term * term
  | Id of ty * term * term

and term = term' * Position.t
and term' =
  | Var of variable
  | Equation of term * (term * term) * term
  | Rewrite of term * (term * term) * term
  | Ascribe of term * ty
  | Lambda of name * ty * ty * term
  | App of (name * ty * ty) * term * term
  | UnitTerm
  | Idpath of ty * term
  | J of ty * (name * name * name * ty) * (name * term) * term * term * term
  | Refl of ty * term
  | Coerce of universe * universe * term
  | NameUnit
  | NameProd of universe * universe * name * term * term
  | NameUniverse of universe
  | NamePaths of universe * term * term * term
  | NameId of universe *term * term * term

(********)
(* Code *)
(********)

(** alpha equivalence of terms, ignoring hints *)
val equal    : term -> term -> bool

(** alpha equivalence of types, ignoring hints inside terms *)
val equal_ty : ty -> ty -> bool

(** [shift delta term] shifts the free variables in [term] by [delta] *)
val shift : int -> term -> term

(** [shift_ty delta ty] shifts the free variables in [ty] by [delta] *)
val shift_ty : int -> ty -> ty

(**
  If [G, x:t |- body : ...] and [G |- arg : t] then
  [beta body arg] is the substituted term [body[x->arg]].

  This is exactly the substitution required, for example, to
  beta-reduce a function application ([body] is the body of the lambda).
*)
val beta    : term -> term -> term

(**
  If [G, x:t |- body : type] and [G |- arg : t] then
  [beta body arg] is the substituted type [body[x->arg]].

  This is exactly the substitution required, for example, to
  to substitute away the parameter in a [Pi] or [Sigma] type ([body] is
  the type of the codomain or second component, respectively).
*)
val beta_ty : ty -> term -> ty


val make_arrow: ?loc:Position.t -> ty -> ty -> ty
(*val make_star : ?loc:Position.t -> ty -> ty -> ty*)

(**
  Suppose we have [G, x_1:t_1, ..., x_n:t_n |- exp : ...] and the inhabitants
  [e_1; ...; e_n] all well-formed in (i.e., indexed relative to) [G] (!).
  Then [strengthen exp [e_1,...,e_n]] is the result of
  substituting away the [x_i]'s, resulting in a term well-formed in [G].

  In particular, [strengthen eBody [eArg]] is just [beta eBody eArg].
 *)
val strengthen    : term -> term list -> term

(** Like [strengthen], but for types *)
val strengthen_ty : ty   -> term list -> ty


(** If [G |- exp : ...] then [G' |- weaken i exp : ...] where [G'] has
    one extra (unused) variable inserted at position [i].

    In particular, [weaken 0 e] is just [shift 1 e].
*)
val weaken : int -> term -> term

(** Like [weaken], but for types *)
val weaken_ty : int -> ty -> ty

