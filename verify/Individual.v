(** * Utilities for proving individual machines *)

From Coq Require Export Lists.Streams.
From Coq Require Import Lia.
From BusyCoq Require Export Permute.
Set Default Goal Selector "!".

Fixpoint repeat {A} (n : nat) (f : A -> A) (a : A) : A :=
  match n with
  | O => a
  | S n => f (repeat n f a)
  end.

Lemma repeat_shift : forall {A} f n (a : A),
  f (repeat n f a) = repeat n f (f a).
Proof.
  induction n; introv.
  - reflexivity.
  - simpl. rewrite IHn. reflexivity.
Qed.

Lemma repeat_S : forall {A} n f (a : A),
  repeat (S n) f a = f (repeat n f a).
Proof. reflexivity. Qed.

Lemma repeat_add : forall A n m f (a : A),
  repeat (n + m) f a = repeat n f (repeat m f a).
Proof.
  introv. induction n.
  - reflexivity.
  - simpl. rewrite IHn. reflexivity.
Qed.

Notation "f :> t" := (f t)  (at level 25, right associativity, only parsing).
Notation "t <: f" := (f t)  (at level 24, left associativity, only parsing).

Module Individual (Ctx : Ctx).
  Module Permute := Permute Ctx. Export Permute.

(** Trivial lemmas, but [simpl] in these situations leaves a mess. *)
Lemma move_left_const : forall s0 s r,
  move_left (const s0 {{s}} r) = const s0 {{s0}} s >> r.
Proof. reflexivity. Qed.

Lemma move_right_const : forall l s s0,
  move_right (l {{s}} const s0) = l << s {{s0}} const s0.
Proof. reflexivity. Qed.

Lemma tl_const : forall A (x : A), tl (const x) = const x.
Proof. reflexivity. Qed.

(** The direct formulation isn't as useful when the proof that the two
    configurations are the same is non-trivial. *)
Lemma evstep_refl' : forall tm c c',
  c = c' ->
  c -[ tm ]->* c'.
Proof. intros. subst c'. auto. Qed.

(** Solve an equality goal where some subexpressions are equal by [lia],
    in an otherwise [reflexivity]-compatible spine. *)
Ltac lia_refl := solve [repeat (lia || f_equal)].

(** [prove_step] proves a goal of the form [c -[ tm ]-> ?c'], where the value
    returned by [tm] in this situation can be calculated by reflexivity. *)
Ltac prove_step_left := apply @step_left; reflexivity.
Ltac prove_step_right := apply @step_right; reflexivity.
Ltac prove_step := prove_step_left || prove_step_right.

(** Simplify a tape expression, removing [move_left] and [move_right] leftover
    after [prove_step], without needlessly expanding the [cofix] in [const s0]. *)
Ltac simpl_tape :=
  try rewrite tl_const;
  try rewrite move_left_const;
  try rewrite move_right_const;
  simpl;
  try rewrite <- const_unfold.

(** Prove a goal of the form [c -->+ c'] that consists of a single TM step. *)
Ltac finish_progress := apply progress_base; prove_step.

(** Prove a goal of the form [c -->* c'] that consists of zero TM steps. *)
Ltac finish_evstep := apply evstep_refl'; try (reflexivity || lia_refl).
Ltac finish := finish_evstep || finish_progress.

(** Advance the configuration on the left-hand side of a [-->+] or [-->*]
    by one TM step. *)
Ltac step := (eapply evstep_step || eapply progress_step); [prove_step | simpl_tape].

(** Run [step] until we reach the state that is being asked for, or until the
    TM gets stuck (because the symbolic state doesn't make it clear what symbol
    is under the tape). *)
Ltac execute := introv; repeat (try solve [finish]; step).

(** For a goal of the form [c -->+ c'], take steps until the TM gets stuck,
    taking at least one step. Transforms the goal into [c'' -->* c'] as a result. *)
Ltac start_progress := eapply progress_intro; [prove_step | simpl_tape]; execute.

(** [follow H], on a goal of the form [H: c1 -->* c2  |-  c1' -->* c3], will
    transform it into [|-  c2 -->* c3].  [adjust] is used to make it work when
    the equality [c1 = c1'] isn't as clear.

    [follow], without an argument, will try using the assumptions
    in the context. *)
Ltac do_adjust H ty :=
  lazymatch ty with
  | _ -> ?ty => do_adjust H ty
  | ?c1 -[ _ ]->* _ =>
    lazymatch goal with
    | |- ?c2 -[ _ ]->* _ =>
      replace c2 with c1; [apply H | reflexivity || lia_refl]
    end
  end.

Ltac adjust H := let ty := type of H in do_adjust H ty.
Ltac adjusted H := apply H || adjust H.
Ltac follow_trans :=
  lazymatch goal with
  | |- _ -[ _ ]->* _ => eapply evstep_trans
  | |- _ -[ _ ]->+ _ => eapply evstep_progress_trans
  end.

Ltac follow_hyp H := follow_trans; [adjusted H; eauto |].
Ltac follow_assm :=
  match goal with
  | H: _ |- _ => follow_hyp H
  end.

Tactic Notation "follow" := follow_assm.
Tactic Notation "follow" constr(H) := follow_hyp H.

(** For trivial [-->*] goals, provable by stepping and applying assumptions. *)
Ltac triv := intros; repeat (try solve [finish]; (step || follow)).

End Individual.
