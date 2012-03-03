
module DDC.Llvm.Module
        ( -- * Modules
          LlvmModule    (..)
        , getGlobalType
        , getGlobalVar

          -- * Static data.
        , LlvmStatic    (..)
        , getStatType)
where
import DDC.Llvm.Function
import DDC.Llvm.Var
import DDC.Llvm.Type
import DDC.Base.Pretty


-- Module ---------------------------------------------------------------------
-- | This is a top level container in LLVM.
data LlvmModule 
        = LlvmModule  
        { -- | Comments to include at the start of the module.
          modComments  :: [LMString]

          -- | Alias type definitions.
        , modAliases   :: [LlvmAlias]

          -- | Global variables to include in the module.
        , modGlobals   :: [LMGlobal]

          -- | Functions used in this module but defined in other modules.
        , modFwdDecls  :: LlvmFunctionDecls

          -- | Functions defined in this module.
        , modFuncs     :: LlvmFunctions
        }

-- | A global mutable variable. Maybe defined or external
type LMGlobal 
        = (LlvmVar, Maybe LlvmStatic)


-- | Return the 'LlvmType' of the 'LMGlobal'
getGlobalType :: LMGlobal -> LlvmType
getGlobalType (v, _)            = getVarType v


-- | Return the 'LlvmVar' part of a 'LMGlobal'
getGlobalVar :: LMGlobal -> LlvmVar
getGlobalVar (v, _) = v


-- Static ---------------------------------------------------------------------
-- | Llvm Static Data.
--  These represent the possible global level variables and constants.
data LlvmStatic
        -- | A comment in a static section.
        = LMComment       LMString

        -- | A static variant of a literal value.
        | LMStaticLit     LlvmLit

        -- | For uninitialised data.
        | LMUninitType    LlvmType

        -- | Defines a static 'LMString'.
        | LMStaticStr     LMString     LlvmType

        -- | A static array.
        | LMStaticArray   [LlvmStatic] LlvmType

        -- | A static structure type.
        | LMStaticStruc   [LlvmStatic] LlvmType

        -- | A pointer to other data.
        | LMStaticPointer LlvmVar

        -- static expressions, could split out but leave
        -- for moment for ease of use. Not many of them.
        -- | Pointer to Pointer conversion.
        | LMBitc LlvmStatic LlvmType                    

        -- | Pointer to Integer conversion.
        | LMPtoI LlvmStatic LlvmType                    

        -- | Constant addition operation.
        | LMAdd  LlvmStatic LlvmStatic                 

        -- | Constant subtraction operation.
        | LMSub  LlvmStatic LlvmStatic  
        deriving (Show)                


-- | Return the 'LlvmType' of the 'LlvmStatic'.
getStatType :: LlvmStatic -> LlvmType
getStatType (LMStaticLit   l  ) = getLitType l
getStatType (LMUninitType    t) = t
getStatType (LMStaticStr   _ t) = t
getStatType (LMStaticArray _ t) = t
getStatType (LMStaticStruc _ t) = t
getStatType (LMStaticPointer v) = getVarType v
getStatType (LMBitc        _ t) = t
getStatType (LMPtoI        _ t) = t
getStatType (LMAdd         t _) = getStatType t
getStatType (LMSub         t _) = getStatType t
getStatType (LMComment       _) = error "Can't call getStatType on LMComment!"


instance Pretty LlvmStatic where
  ppr ss
   = case ss of
        LMComment       s  -> text "; " <> text s
        LMStaticLit   l    -> ppr l
        LMUninitType    t  -> ppr t <> text " undef"
        LMStaticStr   s t  -> ppr t <> text " c\"" <> text s <> text "\\00\""
        LMStaticArray d t  -> ppr t <> text " [" <> hcat (punctuate comma $ map ppr d) <> text "]"
        LMStaticStruc d t  -> ppr t <> text "<{" <> hcat (punctuate comma $ map ppr d) <> text "}>"
        LMStaticPointer v  -> ppr v
        LMBitc v t         -> ppr t <>  text " bitcast" <+> brackets (ppr v <> text " to " <> ppr t)
        LMPtoI v t         -> ppr t <> text " ptrtoint" <+> brackets (ppr v <> text " to " <> ppr t)

        LMAdd s1 s2
         -> let ty1 = getStatType s1
                op  = if isFloat ty1 then text " fadd (" else text " add ("
            in if ty1 == getStatType s2
                then ppr ty1 <> op <> ppr s1 <> comma <> ppr s2 <> text ")"
                else error $ "LMAdd with different types!"

        LMSub s1 s2
         -> let ty1 = getStatType s1
                op  = if isFloat ty1 then text " fsub (" else text " sub ("
            in if ty1 == getStatType s2
                then ppr ty1 <> op <> ppr s1 <> comma <> ppr s2 <> text ")"
                else error $ "LMSub with different types!"