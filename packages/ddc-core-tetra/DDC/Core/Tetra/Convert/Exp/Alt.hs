
module DDC.Core.Tetra.Convert.Exp.Alt
        (convertAlt)
where
import DDC.Core.Tetra.Convert.Exp.Base
import DDC.Core.Tetra.Convert.Data
import DDC.Core.Tetra.Convert.Type
import DDC.Core.Tetra.Convert.Error
import DDC.Core.Compounds
import DDC.Core.Exp
import DDC.Type.DataDef
import DDC.Core.Check                    (AnTEC(..))
import DDC.Control.Monad.Check           (throw)
import qualified DDC.Core.Tetra.Prim     as E
import qualified DDC.Core.Salt.Name      as A
import qualified DDC.Core.Salt.Compounds as A
import qualified Data.Map                as Map


-- | Convert a Lite alternative to Salt.
convertAlt 
        :: Show a
        => a                            -- ^ Annotation from case expression.
        -> Bound E.Name                 -- ^ Bound of scrutinee.
        -> Type  E.Name                 -- ^ Type  of scrutinee
        -> ExpContext                   -- ^ Context of enclosing case-expression.
        -> Context a
        -> Alt (AnTEC a E.Name) E.Name  -- ^ Alternative to convert.
        -> ConvertM a (Alt a A.Name)

convertAlt a uScrut tScrut ectx ctx alt
 = let  pp       = contextPlatform   ctx
        defs     = contextDataDefs   ctx
        kenv     = contextKindEnv    ctx
        convertX = contextConvertExp ctx
        tctx     = typeContext       ctx
   in case alt of
        -- Match against the unit constructor.
        --  This is baked into the langauge and doesn't have a real name,
        --  so we need to handle it separately.
        AAlt (PData dc []) x
         | DaConUnit    <- dc
         -> do  xBody           <- convertX ectx ctx x
                let dcTag       = DaConPrim (A.NameLitTag 0) A.tTag
                return  $ AAlt (PData dcTag []) xBody

        -- Match against literal unboxed values.
        AAlt (PData dc []) x
         | Just nCtor           <- takeNameOfDaCon dc
         , E.isNameLit nCtor
         -> do  dc'             <- convertDaCon tctx dc
                xBody1          <- convertX     ectx ctx  x
                return  $ AAlt (PData dc' []) xBody1

        -- Match against user-defined algebraic data.
        AAlt (PData dc bsFields) x
         | Just nCtor   <- takeNameOfDaCon dc
         , Just ctorDef <- Map.lookup nCtor $ dataDefsCtors defs
         -> do  
                -- Convert the scrutinee.
                uScrut'         <- convertValueU uScrut

                -- Get the tag of this alternative.
                let iTag        = fromIntegral $ dataCtorTag ctorDef
                let dcTag       = DaConPrim (A.NameLitTag iTag) A.tTag
                
                -- Get the address of the payload.
                bsFields'       <- mapM (convertValueB tctx) bsFields       

                -- Convert the right of the alternative, 
                -- with all all the pattern variables in scope.
                let ctx'        = extendsTypeEnv bsFields ctx
                xBody1          <- convertX ectx ctx' x

                -- Determine the prime region of the scrutinee.
                -- This is the region the associated Salt object is in.
                trPrime         <- saltPrimeRegionOfDataType kenv tScrut

                -- Wrap the body expression with let-bindings that bind
                -- each of the fields of the data constructor.
                xBody2          <- destructData pp a ctorDef uScrut' trPrime
                                        bsFields' xBody1

                return  $ AAlt (PData dcTag []) xBody2

        -- Default alternative.
        AAlt PDefault x
         -> do  x'      <- convertX ectx ctx x 
                return  $ AAlt PDefault x'

        AAlt{}          
         -> throw ErrorInvalidAlt
