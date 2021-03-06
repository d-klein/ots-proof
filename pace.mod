--
-- Password Authenticated Connection Establishment
-- (PACE Protocol)
--  H   : Hash
--  M   : MAC
--  D_picc : Domain Parameter
--  pi : Password known by chip and terminal in advance
--  n_x : nonce_x
--  *   : group operation
--
-- 1. chip --> term : D_picc, E(H(pi),n_s)
--  
-- G = maptopoint(n_s,D_picc)                 // shortcut
-- 
-- 2. chip --> term : n_a * G   // = Y_a
-- 3. term --> chip : n_b * G   // = Y_b
-- 4. term --> chip : M(H(nonce_b * Y_a), Y_a, D_picc)
-- 5. chip --> term : M(H(nonce_a * Y_b), Y_b, D_picc)
--
-- chip and terminal accept only if Mac of Y_a resp. Y_b and G can be
-- verified by using the key H(nonce_b * Y_a) resp. H(nonce_a * Y_b) for
-- the Mac

--
-- One of the principals is the intruder denoted by constant intruder.
-- the intruder does not know the secret password pi, shared in advance
--
mod* PRINCIPAL principal-sort Principal {
  [Principal]
  op intruder : -> Principal
  op _=_ : Principal Principal -> Bool {comm}
  op knowspi : Principal -> Bool
  var P : Principal
  eq (P = P) = true .
  eq knowspi(intruder) = false .
}

--
-- Unguessable random numbers
--
mod* RANDOM principal-sort Random {
  [Random]
  op _=_ : Random Random -> Bool {comm}
  vars R R1 R2 : Random
  eq (R = R) = true .
  ceq R1 = R2 if R1 = R2 .
}

--
-- Domain Parameter
--
mod* DOMPAR principal-sort Dompar {
  [Dompar]
  op _=_ : Dompar Dompar -> Bool {comm}
  vars D D1 D2 : Dompar
  eq (D = D) = true .
  ceq D1 = D2 if D1 = D2 .
}

--
-- Element(s) generated by map_to_point
--
mod* MAPPOINT principal-sort Mappoint {
pr(RANDOM + DOMPAR)
  [Mappoint]
  op _=_ : Mappoint Mappoint -> Bool {comm}
  op maptopoint : Random Dompar -> Mappoint
  op rand : Mappoint -> Random
  op dpar : Mappoint -> Dompar
  vars M M1 M2 : Mappoint
  var R : Random
  var D : Dompar
  eq rand(maptopoint(R,D)) = R .
  eq dpar(maptopoint(R,D)) = D .
  eq (M1 = M2) = (rand(M1) = rand(M2) and dpar(M1) = dpar(M2)) .
  eq (M = M) = true .
  ceq M1 = M2 if M1 = M2 .
}

-- 
-- "Exponent" 
-- of applying group operation to self generated nonce
-- and mapped_nonce in step 2 resp. step 3 of the protocol
--
mod* EXPO principal-sort Expo {
pr(RANDOM + MAPPOINT)
  [Expo]
  op _=_ : Expo Expo -> Bool
  op expo : Random Mappoint -> Expo
  op rand : Expo -> Random
  op point : Expo -> Mappoint
  vars E1 E2 : Expo
  var M : Mappoint
  var R : Random
  eq point(expo(R,M)) = M .
  eq rand(expo(R,M)) = R .
  eq (E1 = E2)
     = (rand(E1) = rand(E2) and point(E1) = point(E2)) .
  eq (E1 = E1) = true .
  ceq E1 = E2 if E1 = E2 .
}

--
-- Hash values
-- here we assume that the domain of the hash function
-- is rand * exponent, i.e. the generated DH-Keys
-- 
mod* HASH principal-sort Hash {
pr(RANDOM + EXPO)
  [Hash]
  op hash : Random Expo -> Hash
  op expo : Hash -> Expo
  op rand : Hash -> Random
  op _=_ : Hash Hash -> Bool {comm}
  vars H1 H2 : Hash
  var E : Expo
  var R : Random
  eq expo(hash(R,E)) = E .
  eq rand(hash(R,E)) = R .
  eq (H1 = H2)
     = ((rand(H1) = rand(H2) and expo(H1) = expo(H2)) or 
        (rand(H1) = rand(expo(H2)) and rand(H2) = rand(expo(H1)) 
         and point(expo(H1)) = point(expo(H2)))) .
  eq (H1 = H1) = true .
  ceq H1 = H2 if H1 = H2 .
}


--
-- Given random r and dompar d, enc(r,d) is the 
-- content of the first message. If honest participants
-- exchange this kind of message, it is implicitly assumed
-- to be encrypted with pi
--
mod* CIPHER1 principal-sort Cipher1 {
pr(RANDOM + DOMPAR)
  [Cipher1]
  op enc : Random Dompar -> Cipher1
  op rand : Cipher1 -> Random
  op dpar : Cipher1 -> Dompar
  op _=_ : Cipher1 Cipher1 -> Bool {comm}
  vars C11 C12 : Cipher1
  var R : Random
  var D : Dompar
  eq rand(enc(R,D)) = R .
  eq dpar(enc(R,D)) = D .  
  eq (C11 = C12)
     = (rand(C11) = rand(C12) and dpar(C11) = dpar(C12)) .
  eq (C11 = C11) = true .
  ceq C11 = C12 if C11 = C12 .
}

--
-- Technically we could define Cipher2 here
-- but Cipher2 would be just a wrapper for Expo, since
-- the content of msg2 is just an openly available expo.
-- So it is not needed explicitly
--

--
-- given a hash h (constructed by rand * expo), an exponent e
-- and domain parameters d, the term mac(h,e,d) denotes
-- the mac of of (e,d) generated with the key h
-- i.e. this is the cipher that appears in messages 4. and 5.
-- of pace
-- Cipher3s distinguish between (logically same) hashes
--
mod* CIPHER3 principal-sort Cipher3 {
pr(HASH + EXPO + DOMPAR)
  [Cipher3]
  op mac : Hash Expo Dompar -> Cipher3
  op hash : Cipher3 -> Hash
  op expo : Cipher3 -> Expo
  op dpar : Cipher3 -> Dompar
  op _=_ : Cipher3 Cipher3 -> Bool {comm}
  vars C31 C32 : Cipher3
  var H : Hash
  var E : Expo
  var D : Dompar
  eq hash(mac(H,E,D)) = H .
  eq expo(mac(H,E,D)) = E .
  eq dpar(mac(H,E,D)) = D .
  eq (C31 = C32)
     = (rand(hash(C31)) = rand(hash(C32)) and
        expo(hash(C31)) = expo(hash(C32)) and 
        expo(C31) = expo(C32) and
        dpar(C31) = dpar(C32)) .
  eq (C31 = C31) = true .
  ceq C31 = C32 if C31 = C32 .
}


--
-- Given principals c,s,r and cipheri ei (i = 1,3),
-- resp. expo e2 (for messages 3 and 4 of pace) 
-- mi(c,s,r,ei) resp. mi(c,s,r,e2) denotes a message created by 
-- principal c,
-- but it seems to be sent by principal s to principal r.
--
-- c may be the intruder, and c may be different from s.
-- If c is different from s, then c must be the intruder
-- and the message is faked by the intruder. 
--
mod* MESSAGE principal-sort Message {
pr(PRINCIPAL + CIPHER1 + EXPO + CIPHER3)
  pr(CIPHER1)
  pr(EXPO)
  pr(CIPHER3)
  [Message1 Message2 Message3 < Message]
  --      creator   sender    receiver
  --    --------------------------------------------------
  op me1 : Principal Principal Principal Cipher1 -> Message1 {constr}
  op me2 : Principal Principal Principal Expo -> Message2 {constr}
  op me3 : Principal Principal Principal Cipher3 -> Message3 {constr}
  --
  op creator : Message -> Principal
  op sender : Message -> Principal
  op receiver : Message -> Principal
  op cipher1 : Message1 -> Cipher1
  op expo : Message2 -> Expo
  op cipher3 : Message3 -> Cipher3
  --
  op _=_ : Message Message -> Bool {comm}
  --
  vars M M1 M2 : Message
  vars M11 M12 : Message1
  vars M21 M22 : Message2
  vars M31 M32 : Message3
  vars C S R : Principal
  var E1 : Cipher1
  var E2 : Expo
  var E3 : Cipher3
  --
  eq creator(me1(C,S,R,E1)) = C .
  eq creator(me2(C,S,R,E2)) = C .
  eq creator(me3(C,S,R,E3)) = C .
  eq sender(me1(C,S,R,E1)) = S .
  eq sender(me2(C,S,R,E2)) = S .
  eq sender(me3(C,S,R,E3)) = S .
  eq receiver(me1(C,S,R,E1)) = R .
  eq receiver(me2(C,S,R,E2)) = R .
  eq receiver(me3(C,S,R,E3)) = R .
  eq cipher1(me1(C,S,R,E1)) = E1 .
  eq expo(me2(C,S,R,E2)) = E2 .
  eq cipher3(me3(C,S,R,E3)) = E3 .
  --
  eq (M = M) = true .
  eq (M11 = M12)
     = (creator(M11) = creator(M12) and sender(M11) = sender(M12) and
        receiver(M11) = receiver(M12) and cipher1(M11) = cipher1(M12)) .
  eq (M21 = M22)
     = (creator(M21) = creator(M22) and sender(M21) = sender(M22) and
        receiver(M21) = receiver(M22) and expo(M21) = expo(M22)) .
  eq (M31 = M32)
     = (creator(M31) = creator(M32) and sender(M31) = sender(M32) and
        receiver(M31) = receiver(M32) and cipher3(M31) = cipher3(M32)) .
  eq (M11 = M21) = false .
  eq (M11 = M31) = false .
  eq (M21 = M31) = false .
  ceq M1 = M2 if M1 = M2 .
}

--
-- Formal parameter for the following prameterized module.
--
mod* EQTRIV principal-sort Elt {
  [Elt]
  op _=_ : Elt Elt -> Bool {comm}
  eq (E:Elt = E) = true .
  ceq E1:Elt = E2:Elt if E1 = E2 .
}

--
-- Soup: Bags are one model of this module, but not the only model.
--
mod* SOUP (D :: EQTRIV) principal-sort Soup {
  [Elt.D < Soup]
  op empty : -> Soup {constr}
  op _ _ : Soup Soup -> Soup {constr assoc comm id: empty}
  op _\in_ : Elt.D Soup -> Bool
  var S : Soup
  vars E1 E2 : Elt.D
  --
  eq E1 \in empty = false .
  eq E1 \in (E2 S) = (E1 = E2) or E1 \in S .
}


--
-- The description of the PACE protocol
-- We collect in bags:
--     - all messages that have been sent
--     - all randoms that have been created (to ensure, that fresh
--       randoms are used in step 1, step 2 and 3 of the pace protocol
--     - all randoms created by the intruder (so that the intruder can
--       decide to use fresh randoms or "guess" his own used randoms
--     - all exponents that have been constructed so far 
--       (this is equal to all exponents that the intruder can intercept)
--     - all keys that can be observed (constructed) by the intruder
--
mod* PACE {
  pr(SOUP(MESSAGE)*{sort Soup -> Network})
  pr(SOUP(RANDOM)*{sort Soup -> RandSoup})
  -- pr(SOUP(RANDOM)*{sort Soup -> RandSoupI})
  pr(SOUP(EXPO)*{sort Soup -> ExpoSoup})
  pr(SOUP(HASH)*{sort Soup -> HashSoup})
  pr(SOUP(CIPHER1)*{sort Soup -> Cipher1Soup})
  pr(SOUP(CIPHER3)*{sort Soup -> Cipher3Soup})
  pr(EXPO + RANDOM + DOMPAR + MESSAGE + PRINCIPAL)
  *[System]*
  -- an arbitrary initial state
  op init : -> System {constr}
  -- observers
  bop network : System -> Network       -- Network (soup of messages)
  bop rands : System -> RandSoup        -- all used random numbers
  bop hashes : System -> HashSoup       -- hashes (i.e. keys) gleaned by the intruder
  bop randsi : System -> RandSoup       -- all random numbers created by the intruder
  bop expos : System -> ExpoSoup        -- all transmitted exponents
  bop cipher1s : System -> Cipher1Soup  -- all cipher1's of message1's
  bop cipher3s : System -> Cipher3Soup  -- all cipher3's of message3's
  -- transitions
  -- sending messages according to the protocol
  -- Principal Principal is Source Dest of msg
  bop sdm1 : System Principal Principal Random Dompar -> System {constr}
  bop sdm2 : System Principal Principal Random Message1 -> System {constr}
  bop sdm3 : System Principal Principal Message1 Message2 Message2 -> System {constr}
  -- faking and forging messages based on the gleaned info
  bop fkm11 : System Principal Principal Cipher1    -> System {constr}
  bop fkm12 : System Principal Principal Random Dompar -> System {constr}
  bop fkm21 : System Principal Principal Expo    -> System {constr}
  bop fkm22 : System Principal Principal Random Random Dompar -> System {constr}
  bop fkm31 : System Principal Principal Cipher3    -> System {constr}
  bop fkm32 : System Principal Principal Random Expo Expo Dompar -> System {constr}
  -- CafeOBJ variables
  var S : System
  vars P Q Q? : Principal
  vars R R1 R2 : Random
  vars D D2 : Dompar
  var E : Expo
  vars E1 E2 : Expo
  vars R R1 R2 : Random
  var C1 : Cipher1
  var C3 : Cipher3
  var M1 : Message1
  var M2 : Message2
  var M21 : Message2
  var M22 : Message2
  var M3 : Message3
  -- init
  eq network(init) = empty .
  eq rands(init) = empty .
  eq hashes(init) = empty .
  eq randsi(init) = empty .
  eq expos(init) = empty .
  eq cipher3s(init) = empty .
  -- sdm1
  op c-sdm1 : System Principal Principal Random Dompar -> Bool
  eq c-sdm1(S,P,Q,R,D) = not(R \in rands(S)) .
  --
  ceq network(sdm1(S,P,Q,R,D))  = me1(P,P,Q,enc(R,D)) network(S)
      if c-sdm1(S,P,Q,R,D) .
  ceq rands(sdm1(S,P,Q,R,D))    = R rands(S) if c-sdm1(S,P,Q,R,D) .
  ceq randsi(sdm1(S,P,Q,R,D))   
       = (if Q = intruder and knowspi(intruder) then R randsi(S) else randsi(S) fi)
       if c-sdm1(S,P,Q,R,D) .
   eq hashes(sdm1(S,P,Q,R,D))   = hashes(S) .
   eq expos(sdm1(S,P,Q,R,D))    = expos(S) .
  ceq cipher1s(sdm1(S,P,Q,R,D)) = enc(R,D) cipher1s(S) if c-sdm1(S,P,Q,R,D) .
   eq cipher3s(sdm1(S,P,Q,R,D)) = cipher3s(S) .
  ceq sdm1(S,P,Q,R,D)           = S if not c-sdm1(S,P,Q,R,D) .
  -- sdm2
  -- condition: p can send an exponent to q if
  -- p has sent a message to q with the random to map 
  -- and p knows pi and r is fresh
  -- OR p has received a message seemingly from q  with the random to map
  -- and both p and the original sender know pi
  -- and r is fresh
  op c-sdm2 : System Principal Principal Random Message1 -> Bool
  eq c-sdm2(S,P,Q,R,M1)
     =  (M1 \in network(S) and creator(M1) = P and sender(M1) = P and
         knowspi(P) and not(R \in rands(S))) or
        (M1 \in network(S) and sender(M1) = Q and receiver(M1) = P and
         knowspi(creator(M1)) and knowspi(P) and not (R \in rands(S))) .
  ceq network(sdm2(S,P,Q,R1,M1))  = me2(P,P,Q,expo(R1,maptopoint(rand(cipher1(M1)),dpar(cipher1(M1))))) network(S)
     if c-sdm2(S,P,Q,R1,M1) .
  ceq rands(sdm2(S,P,Q,R1,M1))    = R1 rand(cipher1(M1)) rands(S) if c-sdm2(S,P,Q,R1,M1) .
   eq randsi(sdm2(S,P,Q,R1,M1))   = randsi(S) .
   eq hashes(sdm2(S,P,Q,R1,M1))   = hashes(S) .
  ceq expos(sdm2(S,P,Q,R1,M1)) = expo(R1,maptopoint(rand(cipher1(M1)),dpar(cipher1(M1)))) expos(S) 
        if c-sdm2(S,P,Q,R1,M1) .
   eq cipher1s(sdm2(S,P,Q,R1,M1)) = cipher1s(S) .
   eq cipher3s(sdm2(S,P,Q,R1,M1)) = cipher3s(S) .
  ceq sdm2(S,P,Q,R1,M1)           = S if not c-sdm2(S,P,Q,R1,M1) .
 -- sdm3
  -- If terminal is p: we have to have received m1, sent m2 and received m2
  -- If chip is p: we have to have sent m1, received m2, and received m2
  op c-sdm3 : System Principal Principal Message1 Message2 Message2 -> Bool
  eq c-sdm3(S,P,Q,M1,M21,M22) 
     = M1 \in network(S) and M21 \in network(S) and M22 \in network(S) 
          and rand(cipher1(M1)) = rand(point(expo(M22))) 
          and sender(M21) = Q and receiver(M21) = P
          and creator(M22) = P and sender(M22) = P and receiver(M22) = Q
          and rand(cipher1(M1)) = rand(point(expo(M22))) 
          and dpar(cipher1(M1)) = dpar(point(expo(M22)))
          and ( (sender(M1) = Q and receiver(M1) = P and knowspi(creator(M1)) and knowspi(P)) 
             or (creator(M1) = P and sender(M1) = P and knowspi(P) and receiver(M1) = Q) ) .
  ceq network(sdm3(S,P,Q,M1,M21,M22))  = me3(P,P,Q,mac(hash(rand(expo(M22)),expo(M21)),expo(M21),dpar(cipher1(M1)))) network(S) 
     if c-sdm3(S,P,Q,M1,M21,M22) .
  eq rands(sdm3(S,P,Q,M1,M21,M22))     = rands(S) .
  eq randsi(sdm3(S,P,Q,M1,M21,M22))    = randsi(S) .
  eq hashes(sdm3(S,P,Q,M1,M21,M22))    = hashes(S) .
  eq expos(sdm3(S,P,Q,M1,M21,M22))     = expos(S) . 
  eq cipher1s(sdm3(S,P,Q,M1,M21,M22))  = cipher1s(S) .
 ceq cipher3s(sdm3(S,P,Q,M1,M21,M22))  = mac(hash(rand(expo(M22)),expo(M21)),expo(M21),dpar(cipher1(M1))) cipher3s(S) if c-sdm3(S,P,Q,M1,M21,M22) .
 ceq sdm3(S,P,Q,M1,M21,M22)           = S if not c-sdm3(S,P,Q,M1,M21,M22) .
  -- fkm11
  op c-fkm11 : System Principal Principal Cipher1 -> Bool
  eq c-fkm11(S,P,Q,C1) = C1 \in cipher1s(S) .
  --
 ceq network(fkm11(S,P,Q,C1))   = me1(intruder,P,Q,C1) network(S)
      if c-fkm11(S,P,Q,C1) .
   eq rands(fkm11(S,P,Q,C1))    = rands(S) .
   eq randsi(fkm11(S,P,Q,C1))   = randsi(S) .
   eq hashes(fkm11(S,P,Q,C1))   = hashes(S) .
   eq expos(fkm11(S,P,Q,C1))    = expos(S) .
   eq cipher1s(fkm11(S,P,Q,C1)) = cipher1s(S) .
   eq cipher3s(fkm11(S,P,Q,C1)) = cipher3s(S) .
  ceq fkm11(S,P,Q,C1)           = S if not c-fkm11(S,P,Q,C1) .
  -- fkm12
  op c-fkm12 : System Principal Principal Random Dompar -> Bool
  eq c-fkm12(S,P,Q,R,D) = (not (R \in rands(S))) or (R \in randsi(S)) .
  --
  ceq network(fkm12(S,P,Q,R,D))  = me1(intruder,P,Q,enc(R,D)) network(S)
      if c-fkm12(S,P,Q,R,D) .
  ceq randsi(fkm12(S,P,Q,R,D))   = R randsi(S) if c-fkm12(S,P,Q,R,D) .
  ceq rands(fkm12(S,P,Q,R,D))    = R rands(S) if c-fkm12(S,P,Q,R,D) .
   eq hashes(fkm12(S,P,Q,R,D))   = hashes(S) .
   eq expos(fkm12(S,P,Q,R,D))    = expos(S) .
   eq cipher1s(fkm12(S,P,Q,R,D)) = enc(R,D) cipher1s(S) .
   eq cipher3s(fkm12(S,P,Q,R,D)) = cipher3s(S) .
  ceq fkm12(S,P,Q,R,D)           = S if not c-fkm12(S,P,Q,R,D) .
  -- fkm21
  op c-fkm21 : System Principal Principal Expo -> Bool
  eq c-fkm21(S,P,Q,E) = E \in expos(S) .
  --
  ceq network(fkm21(S,P,Q,E))  = me2(intruder,P,Q,E) network(S)
      if c-fkm21(S,P,Q,E) .
   eq rands(fkm21(S,P,Q,E))    = rand(point(E)) rand(E) rands(S) .
   eq randsi(fkm21(S,P,Q,E))   = randsi(S) .
   eq hashes(fkm21(S,P,Q,E))   = hashes(S) .
   eq expos(fkm21(S,P,Q,E))    = expos(S) .
   eq cipher1s(fkm21(S,P,Q,E)) = cipher1s(S) .
   eq cipher3s(fkm21(S,P,Q,E)) = cipher3s(S) .
  ceq fkm21(S,P,Q,E)           = S if not c-fkm21(S,P,Q,E) .
  -- fkm22
  -- the only condition is, that first rand is fresh or has been used before
  -- and the second rand should been created before by the intruder
  -- note that the intruder can always create an arbitrary nonce
  -- by sending a message1 to himself with a fresh rand
  op c-fkm22 : System Principal Principal Random Random Dompar -> Bool
  eq c-fkm22(S,P,Q,R1,R2,D)
      = (R1 \in randsi(S) and R2 \in randsi(S)) or (not (R1 \in rands(S)) and R2 \in randsi(S)) .
  --
  ceq network(fkm22(S,P,Q,R1,R2,D))  = me2(intruder,P,Q,expo(R1,maptopoint(R2,D))) network(S)
      if c-fkm22(S,P,Q,R1,R2,D) .
   eq rands(fkm22(S,P,Q,R1,R2,D))    = R1 R2 rands(S) .
   eq randsi(fkm22(S,P,Q,R1,R2,D))   = R1 R2 randsi(S) .
   eq hashes(fkm22(S,P,Q,R1,R2,D))   = hashes(S) .
  ceq expos(fkm22(S,P,Q,R1,R2,D))   =  expo(R1,maptopoint(R2,D)) expos(S) if c-fkm22(S,P,Q,R1,R2,D) .
   eq cipher1s(fkm22(S,P,Q,R1,R2,D)) = cipher1s(S) .
   eq cipher3s(fkm22(S,P,Q,R1,R2,D)) = cipher3s(S) .
  ceq fkm22(S,P,Q,R1,R2,D)           = S if not c-fkm22(S,P,Q,R1,R2,D) .
  -- fkm31
  op c-fkm31 : System Principal Principal Cipher3 -> Bool
  eq c-fkm31(S,P,Q,C3) = C3 \in cipher3s(S) .
  --
  ceq network(fkm31(S,P,Q,C3))  = me3(intruder,P,Q,C3) network(S)
      if c-fkm31(S,P,Q,C3) .
   eq rands(fkm31(S,P,Q,C3))    = rands(S) .
   eq randsi(fkm31(S,P,Q,C3))   = randsi(S) .
   eq hashes(fkm31(S,P,Q,C3))   = hashes(S) .
   eq expos(fkm31(S,P,Q,C3))    = expos(S) .
   eq cipher1s(fkm31(S,P,Q,C3)) = cipher1s(S) .
   eq cipher3s(fkm31(S,P,Q,C3)) = cipher3s(S) .
  ceq fkm31(S,P,Q,C3)           = S if not c-fkm31(S,P,Q,C3) .
  -- fkm32
  -- condition is that R is either freshly created or has been created by
  -- the intruder before, and E1 and E2 appeared before
  -- note that intruder can create arbitrary E1 and E2 due sending
  -- a fake message2 to himself
  op c-fkm32 : System Principal Principal Random Expo Expo Dompar -> Bool
  eq c-fkm32(S,P,Q,R,E1,E2,D) = 
     ((R \in randsi(S)) or not (R \in rands(S))) and
       E1 \in expos(S) and E2 \in expos(S) .
  --
  ceq network(fkm32(S,P,Q,R,E1,E2,D))  = me3(intruder,P,Q,mac(hash(R,E1),E2,D)) network(S)
      if c-fkm32(S,P,Q,R,E1,E2,D) .
  ceq rands(fkm32(S,P,Q,R,E1,E2,D))    = R rands(S) if c-fkm32(S,P,Q,R,E1,E2,D) .
  ceq randsi(fkm32(S,P,Q,R,E1,E2,D))   = R randsi(S) if c-fkm32(S,P,Q,R,E1,E2,D) .
  ceq hashes(fkm32(S,P,Q,R,E1,E2,D))   = hash(R,E1) hashes(S) if c-fkm32(S,P,Q,R,E1,E2,D) .
   eq expos(fkm32(S,P,Q,R,E1,E2,D))    = expos(S) .
   eq cipher1s(fkm32(S,P,Q,R,E1,E2,D)) = cipher1s(S) .
  ceq cipher3s(fkm32(S,P,Q,R,E1,E2,D)) = mac(hash(R,E1),E2,D) cipher3s(S) if c-fkm32(S,P,Q,R,E1,E2,D) .
  ceq fkm32(S,P,Q,R,E1,E2,D)           = S if not c-fkm32(S,P,Q,R,E1,E2,D) .
}
