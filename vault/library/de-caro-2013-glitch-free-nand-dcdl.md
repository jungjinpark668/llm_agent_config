---
date: 2026-11-24
tags: [vlsi, dll, delay-line, glitch-free, paper]
type: concept
status: active
---

# De Caro 2013: glitch-free NAND-based digitally controlled delay line

Source: D. De Caro, "Glitch-Free NAND-Based Digitally Controlled Delay-Lines," IEEE TVLSI 21(1):55-66, 2013. Zotero item 4AZ69X3C (collection VLSI). All 12 pages were read on 2026-11-24. Figures 4, 5, 7 and the Appendix were rendered at 400-800 dpi with pdftoppm, because `zotero-cli read --format image` failed.

Used in hive_2026 as a side scratch: [[2026-11-24-glitch-free-line-scratch]].

## Terms
- DE: one delay element of the line.
- t_NAND (t): the delay of one NAND2 stage.
- c: the turning DE. The input edge goes forward up to DE c, turns there, and comes back.
- S_i, T_i: the two control bits of DE i.
- A pin: the fast input of the NAND2. On TSMC ND2D1 this is A1; A2 is the bottom NMOS.
- t_S,HL: the time S falls. t_T,LH: the time T rises. The other combinations are named the same way.

## Delay element (Fig. 4)
Each DE has 4 working NAND2 and 2 dummy NAND2 (Table II: normalized MOS count 1.5).
- g1 = NAND(A = alpha_i, 1): the forward path. Its output alpha_o is alpha_i of DE i+1.
- g2 = NAND(A = alpha_i, T_i). Its output is x.
- g3 = NAND(A = S_i, x). Its output is y.
- g4 = NAND(A = beta_i, B = y): the return path. beta_i is the g4 output of DE i+1.
- dmy1 = NAND(A = x, 1) and dmy2 = NAND(A = beta_i, y). Their outputs are unused.
- Purpose of the dummies: every node drives exactly two NAND inputs, so every NAND has the same load and the same delay.

## Control code
- S is thermometric: S_i = 0 for i < c, otherwise 1.
- T is one-cold: T_{c+1} = 0, all other T = 1.
- DE states (Table I): Pass (i < c), Turn (i = c), Post-Turn (i = c+1).
- Every forward and return node toggles with the input, except beta_c (Sec. III). So the whole line switches every cycle.

## Non-inverting line (Fig. 5)
- DE 0 keeps only g3 (A = S_0, B = In), g4 and dmy2. DE 1 takes In as alpha_i.
- Delay for code c is (2 + 2c) t_NAND. Minimum delay 2 t_NAND; step 2 t_NAND.

## Code switching rules (Sec. IV)
The switch is two-step: T changes first, then S.
- Eq. (2): t_S,HL - t_T,LH > t_NAND. Eq. (3): t_T,HL - t_S,LH > -3 t_NAND.
- Eq. (4) defines Delta_s = t_S,HL - t_T,LH (used in up steps) and Delta_t = t_S,LH - t_T,HL (used in down steps).
- Eq. (5): Delta_s > t_NAND. Eq. (6): Delta_t < 3 t_NAND. Fig. 10 shows these are the worst cases.
- Fig. 7(a) driver:
  - T comes straight from a register.
  - S comes from a register through 3 NAND2: S = NAND(Q, NAND(NAND(Q, 1), 1)).
  - So S rises after 1 t_NAND and falls after 3 t_NAND.
  - Result: Delta_s = 3t and Delta_t = t, a margin of 2t on both rules (eq. 7).
  - This assumes the S and T registers switch at the same time and all NANDs have the same delay.
- Fig. 7(b), eqs. (8)-(10): with one delay Delta, the rule is t_NAND < Delta < 3 t_NAND. The best value is Delta = 2 t_NAND, with a margin of t_NAND.

## Appendix: what "glitch-free" assumes
- Table VI lists 20 switching cases. The rules apply in cases #4 and #6 (eq. 3) and #13 and #14 (eq. 2). Case #14 is a single up step; case #6 is a single down step.
- Eq. (12) is t_T,LH + 3t - (t_S,HL + t) < t. The paper assumes that if the two inputs of a NAND overlap for less than t_NAND, the output does not glitch.
- Without that assumption (no input overlap at all), the rules are stricter:
  - Up step: Delta_s > 2t.
  - Down step: Delta_t < 2t.
  - With these strict rules, the Fig. 7(a) margin is 1t on each rule, not 2t.
- Derivation for the down step (checked against the hive_2026 gate sim): the race margin at g4 of the new turning DE is 2t - Delta_t.
- Sec. II precondition: the new code must reach the switching DE before the input edge does. The Appendix proof assumes a static input.
