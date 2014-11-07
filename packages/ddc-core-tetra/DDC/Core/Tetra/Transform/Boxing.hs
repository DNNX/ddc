
module DDC.Core.Tetra.Transform.Boxing
        (boxingModule)
where
import DDC.Core.Tetra.Compounds
import DDC.Core.Tetra.Prim
import DDC.Core.Transform.Boxing
import DDC.Core.Module
import DDC.Core.Exp


-- | Manage boxing of numeric values in a module.
boxingModule :: Show a => Module a Name -> Module a Name
boxingModule mm
        = boxing config mm


-- | Tetra-specific configuration for boxing transform.
config :: Config a Name
config  = Config
        { configRepOfType               = repOfType
        , configConvertRepType          = convertRepType
        , configNameIsUnboxedOp         = isNameOfUnboxedOp 
        , configValueTypeOfLitName      = takeTypeOfLitName
        , configValueTypeOfPrimOpName   = takeTypeOfPrimOpName
        , configValueTypeOfForeignName  = const Nothing
        , configBoxedOfValue            = boxedOfValue
        , configValueOfBoxed            = valueOfBoxed
        , configBoxedOfUnboxed          = boxedOfUnboxed
        , configUnboxedOfBoxed          = unboxedOfBoxed }


-- | Get the representation of a given type.
repOfType :: Type Name -> Maybe Rep
repOfType tt
        -- These types are listed out in full so anyone who adds more
        -- constructors to the PrimTyCon type is forced to specify what
        -- the representation is.
        | Just (NamePrimTyCon n, _)     <- takePrimTyConApps tt
        = case n of
                PrimTyConVoid           -> Just RepNone

                PrimTyConBool           -> Just RepValue
                PrimTyConNat            -> Just RepValue
                PrimTyConInt            -> Just RepValue
                PrimTyConWord{}         -> Just RepValue
                PrimTyConFloat{}        -> Just RepValue
                PrimTyConVec{}          -> Just RepValue
                PrimTyConAddr{}         -> Just RepValue
                PrimTyConPtr{}          -> Just RepValue
                PrimTyConTag{}          -> Just RepValue
                PrimTyConString{}       -> Just RepValue

        -- These are all higher-kinded type constructors,
        -- which don't have any associated values.
        | Just (NameTyConTetra n, _)    <- takePrimTyConApps tt
        = case n of
                TyConTetraRef{}         -> Just RepNone
                TyConTetraTuple{}       -> Just RepNone
                TyConTetraB{}           -> Just RepNone
                TyConTetraU{}           -> Just RepNone
                TyConTetraF{}           -> Just RepNone
                TyConTetraC{}           -> Just RepNone

        -- Explicitly boxed things.
        | Just (n, _)   <- takePrimTyConApps tt
        , NameTyConTetra TyConTetraB    <- n
        = Just RepBoxed

        -- Explicitly unboxed things.
        | Just (n, _)   <- takePrimTyConApps tt
        , NameTyConTetra TyConTetraU    <- n
        = Just RepUnboxed

        | otherwise
        = Nothing


-- | Get the type for a different representation of the given one.
convertRepType :: Rep -> Type Name -> Maybe (Type Name)

convertRepType RepValue tt
        -- Produce the value type from a boxed one.
        | Just (n, [t]) <- takePrimTyConApps tt
        , NameTyConTetra TyConTetraB    <- n
        = Just t

        -- Produce the value type from an unboxed one.
        | Just (n, [t]) <- takePrimTyConApps tt
        , NameTyConTetra TyConTetraU    <- n
        = Just t


convertRepType RepBoxed tt
        -- Produce the boxed version of a value type.
        | Just (NamePrimTyCon tc, [])   <- takePrimTyConApps tt
        = case tc of
                PrimTyConBool           -> Just $ tBoxed tBool
                PrimTyConNat            -> Just $ tBoxed tNat
                PrimTyConInt            -> Just $ tBoxed tInt
                PrimTyConWord  bits     -> Just $ tBoxed (tWord  bits)
                _                       -> Nothing

        -- Produce the unbxed version of a value type.
        | Just (NamePrimTyCon tc, [])   <- takePrimTyConApps tt
        = case tc of
                PrimTyConBool           -> Just $ tUnboxed tBool
                PrimTyConNat            -> Just $ tUnboxed tNat
                PrimTyConInt            -> Just $ tUnboxed tInt
                PrimTyConWord  bits     -> Just $ tUnboxed (tWord  bits)
                _                       -> Nothing

convertRepType _ _
        = Nothing


-- | Check if the primitive operator with this name takes unboxed values
--   directly.
isNameOfUnboxedOp :: Name -> Bool
isNameOfUnboxedOp nn
 = case nn of
        NamePrimArith{} -> True
        NamePrimCast{}  -> True
        _               -> False


-- | Wrap a pure value into its boxed representation.
boxedOfValue :: a -> Exp a Name -> Type Name -> Maybe (Exp a Name)
boxedOfValue a xx tt
        | Just tBx      <- convertRepType RepBoxed tt
        = Just $ xCastConvert a tt tBx xx

        | otherwise     = Nothing


-- | Unwrap a boxed value.
valueOfBoxed :: a -> Exp a Name -> Type Name -> Maybe (Exp a Name)
valueOfBoxed a xx tt
        | Just tBx      <- convertRepType RepBoxed tt
        = Just $ xCastConvert a tBx tt xx

        | otherwise     = Nothing


-- | Box an expression of the given type.
boxedOfUnboxed :: a -> Exp a Name -> Type Name -> Maybe (Exp a Name)
boxedOfUnboxed a xx tt
        | Just tBx      <- convertRepType RepBoxed   tt
        , Just tUx      <- convertRepType RepUnboxed tt
        = Just $ xCastConvert a tUx tBx xx

        | otherwise     = Nothing


-- | Unbox an expression of the given type.
unboxedOfBoxed :: a -> Exp a Name -> Type Name -> Maybe (Exp a Name)
unboxedOfBoxed a xx tt
        | Just tBx      <- convertRepType RepBoxed   tt 
        , Just tUx      <- convertRepType RepUnboxed tt
        = Just $ xCastConvert a tBx tUx xx

        | otherwise     = Nothing

