
module DDC.Core.Tetra.Convert.Exp.PrimBoxing
        (convertPrimBoxing)
where
import DDC.Core.Tetra.Convert.Exp.Base
import DDC.Core.Tetra.Convert.Boxing
import DDC.Core.Tetra.Convert.Data
import DDC.Core.Tetra.Convert.Type
import DDC.Core.Tetra.Convert.Error

import DDC.Core.Transform.BoundX
import DDC.Core.Compounds
import DDC.Core.Exp
import DDC.Core.Check                    (AnTEC(..))
import qualified DDC.Core.Tetra.Prim     as E
import qualified DDC.Core.Salt.Runtime   as A
import qualified DDC.Core.Salt.Name      as A
import qualified DDC.Core.Salt.Compounds as A


-- | Convert a Tetra boxing primop to Salt.
convertPrimBoxing
        :: Show a 
        => ExpContext                   -- ^ The surrounding expression context.
        -> Context a                    -- ^ Types and values in the environment.
        -> Exp (AnTEC a E.Name) E.Name  -- ^ Expression to convert.
        -> Maybe (ConvertM a (Exp a A.Name))

convertPrimBoxing _ectx ctx xx
 = let  pp        = contextPlatform ctx
        kenv      = contextKindEnv  ctx
        tenv      = contextTypeEnv  ctx
 
        convertX  = contextConvertExp  ctx
        downArgX  = convertX           ExpArg ctx 

   in case xx of

        ---------------------------------------------------
        -- Boxing of unboxed numeric values.
        --   The unboxed representation of a numeric value is the machine value.
        --   We fake-up a data-type declaration so we can use the same data layout
        --   code as for user-defined types.
        XApp a _ _
         | Just ( E.NamePrimCast E.PrimCastConvert
                , [XType _ tUx, XType _ tBx, xArg])     <- takeXPrimApps xx
         , isUnboxedRepType tUx
         , isNumericType    tBx
         , Just dt      <- makeBoxedPrimDataType tBx
         , Just dc      <- makeBoxedPrimDataCtor tBx
         -> Just $ do  
                let a'  = annotTail a
                xArg'   <- downArgX xArg
                tUx'    <- convertNumericT tBx

                constructData pp kenv tenv a'
                        dt dc A.rTop [xArg'] [tUx']


        -- Unboxing of boxed values.
        --   The unboxed representation of a numeric value is the machine value.
        --   We fake-up a data-type declaration so we can use the same data layout
        --   code as for used-defined types.
        XApp a _ _
         | Just ( E.NamePrimCast E.PrimCastConvert
                , [XType _ tBx, XType _ tUx, xArg])     <- takeXPrimApps xx
         , isUnboxedRepType tUx
         , isNumericType    tBx
         , Just dc      <- makeBoxedPrimDataCtor tBx
         -> Just $ do
                let a'  = annotTail a
                xArg'   <- downArgX xArg
                tBx'    <- convertValueT (typeContext ctx) tBx
                tUx'    <- convertNumericT tBx

                x'      <- destructData pp a' dc
                                (UIx 0) A.rTop 
                                [BAnon tUx'] (XVar a' (UIx 0))

                return  $ XLet a' (LLet (BAnon tBx') (liftX 1 xArg')) x'

        ---------------------------------------------------
        -- Boxing of unboxed strings
        XApp a _ _
         | Just ( E.NamePrimCast E.PrimCastConvert
                , [XType _ tUx, XType _ tBx, xArg])  <- takeXPrimApps xx
         , tUx == E.tUnboxed E.tString
         , tBx == E.tString
         -> Just $ do  
                let a'   = annotTail a
                xArg'    <- downArgX xArg
                let dt   = makeBoxedStringDataType
                let dc   = makeBoxedStringDataCtor
                let tUx' = A.tPtr A.rTop (A.tWord 8)

                constructData pp kenv tenv a'
                        dt dc A.rTop [xArg'] [tUx']

        -- Unboxing of boxed strings.
        XApp a _ _
         | Just ( E.NamePrimCast E.PrimCastConvert
                , [XType _ tBx, XType _ tUx, xArg])     <- takeXPrimApps xx
         , tBx == E.tString
         , tUx == E.tUnboxed E.tString
         -> Just $ do
                let a'   = annotTail a
                xArg'    <- downArgX xArg
                let dc   = makeBoxedStringDataCtor
                let tUx' = A.tPtr A.rTop (A.tWord 8)
                let tBx' = A.tPtr A.rTop (A.tObj)

                x'       <- destructData pp a' dc
                                (UIx 0) A.rTop 
                                [BAnon tUx'] (XVar a' (UIx 0))

                return  $ XLet a' (LLet (BAnon tBx') (liftX 1 xArg')) x'


        ---------------------------------------------------
        -- This isn't a boxing primitive.
        _ -> Nothing

