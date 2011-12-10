
-- | Primitive types and operators for the interpreter.
--
--   These are only a subset of the primitives supported by the real compiler, there's just
--   enough to experiment with the core language. When we end up wanting to interpret full
--   Disciple programs, we should use the primops defined by the real compiler.
--
module DDCI.Core.Prim.Env
        ( primEnv
        , typeOfPrimName
        , tInt
        , tUnit)
where
import DDCI.Core.Prim.Name
import DDC.Type.Exp
import DDC.Type.Compounds
import DDC.Type.Env             (Env)
import qualified DDC.Type.Env   as Env


-- | Environment containing just the primitive names.
primEnv :: Env Name
primEnv = Env.setPrim typeOfPrimName Env.empty


-- | Take the type of a primitive name.
--
--   Returns `Nothing` if the name isn't primitive. During checking, non-primitive
--   names should be bound in the type environment.
--
typeOfPrimName :: Name -> Maybe (Type Name)
typeOfPrimName nn
 = case nn of
        NameRgn _
         -> Just $ kRegion

        -- All ints have the same type.
        NameInt _
         -> Just $ tForall kRegion
          $ \r  -> tFun tUnit (tAlloc r)
                              (tBot kClosure)
                 $ tInt r
        
        -- unit
        NamePrimCon PrimDaConUnit       -> Just $ tUnit 
        
        -- neg
        NamePrimOp PrimOpNeg
         -> Just $ tForalls [kRegion, kRegion] $ \[r1, r0]
                -> tFun (tInt r1) (tSum kEffect  [tRead r1, tAlloc r0])
                                  (tBot kClosure)
                      $ (tInt r0)

        -- add, sub
        NamePrimOp p
         | elem p [PrimOpAdd, PrimOpSub]
         -> Just $ tForalls [kRegion, kRegion, kRegion] $ \[r2, r1, r0] 
                -> tFun (tInt r2) (tBot kEffect)
                                  (tBot kClosure)
                 $ tFun (tInt r1) (tSum kEffect  [tRead r2, tRead r1, tAlloc r0])
                                  (tSum kClosure [tShare r2])
                 $ tInt r0
                 
        _ -> Nothing


-- | Application of the Int type constructor.
tInt :: Region Name -> Type Name
tInt r1 = tConData1 (NamePrimCon PrimTyConInt) (kFun kRegion kData) r1

-- | The Unit type constructor.
tUnit :: Type Name
tUnit   = tConData0 (NamePrimCon PrimTyConUnit) kData
