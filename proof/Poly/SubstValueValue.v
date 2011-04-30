
Require Import SubstTypeType.
Require Import SubstTypeValue.
Require Import TyJudge.
Require Import KiJudge.
Require Import Exp.
Require Import Env.
Require Import Base.


(* Lift value indices in expressions.
   That are greater or equal to a given depth. *)
Fixpoint liftXX (d: nat) (xx: exp) : exp :=
  match xx with
  |  XVar ix    
  => if le_gt_dec d ix
      then XVar (S ix)
      else xx

  |  XLAM x
  => XLAM (liftXX d x)

  |  XAPP x t
  => XAPP (liftXX d x) t
 
  |  XLam t x   
  => XLam t (liftXX (S d) x)

  |  XApp x1 x2
  => XApp (liftXX d x1) (liftXX d x2)
 end.


(* Substitution of Exps in Exps *)
Fixpoint substXX (d: nat) (u: exp) (xx: exp) : exp :=
  match xx with
  | XVar ix    
  => match nat_compare ix d with
     | Eq => u
     | Gt => XVar (ix - 1)
     | _  => XVar  ix
     end

  |  XLAM x
  => XLAM (substXX d (liftTX 0 u) x)

  |  XAPP x t
  => XAPP (substXX d u x) t

  |  XLam t x
  => XLam t (substXX (S d) (liftXX 0 u) x)

  |  XApp x1 x2
  => XApp (substXX d u x1) (substXX d u x2)
  end.


(* Weakening Kind Env in TyJudge ************************************
   We can insert a new kind into the kind environment of a type
   judgement, provided we lift existing references to kinds higher
   than this in the stack over the new one.

   References to existing elements of the kind environment may
   appear in the type environment, expression, as well as the
   resulting type -- so we have to lift all of them.
 *)
Lemma type_kienv_insert
 :  forall ke te ix x1 t1 k2
 ,  TYPE ke                 te             x1             t1
 -> TYPE (insert ix k2 ke) (liftTE ix te) (liftTX ix x1) (liftTT ix t1).
Proof. admit. Qed.


Lemma type_kienv_weaken
 :  forall ke te x1 t1 k2
 ,  TYPE ke                 te            x1              t1
 -> TYPE (ke :> k2)        (liftTE 0 te) (liftTX 0 x1)   (liftTT 0 t1).
Proof.
 intros.
 assert (ke :> k2 = insert 0 k2 ke). 
  destruct ke; auto. rewrite H0.
  apply type_kienv_insert. auto.
Qed.


(* Weakening Type Env in TyJudge ************************************
   We can insert a new type into the type environment of a type 
   judgement, provided we lift existing references to types higher
   than this in the stack over the new one.
 *)
Lemma type_tyenv_insert
 :  forall ke te ix x1 t1 t2
 ,  TYPE ke  te                x1            t1
 -> TYPE ke (insert ix t2 te) (liftXX ix x1) t1.
Proof. 
 intros. gen ix ke te t1 t2.
 induction x1; intros; simpl; inverts H; eauto.

 Case "XVar".
  lift_cases; intros; auto.

 Case "XLAM".
  apply TYLAM. simpl.
  assert ( liftTE 0 (insert ix t2 te)
         = insert ix (liftTT 0 t2) (liftTE 0 te)). 
   unfold liftTE. rewrite map_insert. auto.
  rewrite H.
  apply IHx1. auto.

 Case "XLam".
  eapply TYLam.
  rewrite insert_rewind.
  apply IHx1. auto.
Qed.


Lemma type_tyenv_weaken
 :  forall ke te x1 t1 t2
 ,  TYPE ke  te         x1           t1
 -> TYPE ke (te :> t2) (liftXX 0 x1) t1.
Proof.
 intros.
 assert (te :> t2 = insert 0 t2 te).
  destruct te; auto. rewrite H0.
  apply type_tyenv_insert. auto.
Qed.


(* Substitution of Values in Values preserves Typing ****************)
Theorem subst_value_value_ix
 :  forall ix ke te x1 t1 x2 t2
 ,  get  te ix = Some t2
 -> TYPE ke te           x1 t1
 -> TYPE ke (drop ix te) x2 t2
 -> TYPE ke (drop ix te) (substXX ix x2 x1) t1.
Proof.
 intros. gen ix ke te t1 x2 t2.
 induction x1; intros; inverts H0; simpl; eauto.

 Case "XVar".
  fbreak_nat_compare.
  SCase "n = ix".
   rewrite H in H5. inverts H5. auto.

  SCase "n < ix".
   apply TYVar. 
   rewrite <- H5. apply get_drop_above. auto.

  SCase "n > ix".
   apply TYVar. auto.
   rewrite <- H5.
   destruct n.
    burn.
    simpl. nnat. apply get_drop_below. omega.

 Case "XLAM".
  eapply (IHx1 ix) in H5.
  apply TYLAM.
   unfold liftTE. rewrite map_drop. eauto.
   eapply get_map. eauto.
   unfold liftTE. rewrite <- map_drop.
    assert (map (liftTT 0) (drop ix te) = liftTE 0 (drop ix te)). 
     unfold liftTE. auto. rewrite H0. clear H0.
    apply type_kienv_weaken. auto.

 Case "XLam".
  apply TYLam.
  rewrite drop_rewind.
  eapply IHx1; eauto.
  simpl. apply type_tyenv_weaken. auto.
Qed.


Theorem subst_value_value
 :  forall ke te x1 t1 x2 t2
 ,  TYPE ke (te :> t2) x1 t1
 -> TYPE ke te x2 t2
 -> TYPE ke te (substXX 0 x2 x1) t1.
Proof.
 intros.
 assert (te = drop 0 (te :> t2)). auto.
 rewrite H1. eapply subst_value_value_ix; eauto. eauto.
Qed.




