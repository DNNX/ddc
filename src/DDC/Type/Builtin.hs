{-# OPTIONS -fwarn-incomplete-patterns -fwarn-unused-matches -fwarn-name-shadowing #-}
-- | Short names for built-in types and kinds.
module DDC.Type.Builtin 
	( 
	-- * Atomic kind constructors
	  kBox, kValue, kRegion, kEffect, kClosure
	
	-- * Witness kind constructors
	, kConst,   kDeepConst
	, kMutable, kDeepMutable
	, kLazy,    kHeadLazy
	, kDirect
	, kPure
	, kEmpty
	
	-- * Bottom effect and closure
	, tBot, tPure, tEmpty

	-- * Effect constructors
	, tRead,  tDeepRead, tHeadRead
	, tWrite, tDeepWrite
	
	-- * Closure constructors
	, tFree, tFreeType, tFreeRegion, tDanger
	
	-- * Witness type constructors
	, tMkConst,   tMkDeepConst
	, tMkMutable, tMkDeepMutable
	, tMkLazy,    tMkHeadLazy
	, tMkDirect
	, tMkPurify,  tMkPure
	
	-- * Elaboration constructors
	, tElaborateRead
	, tElaborateWrite
	, tElaborateModify
	
	-- * Plain constructors for primitive types
	, tcBool
	, tcWord
	, tcInt
	, tcFloat
	, tcChar
	, tcTyDataBits
	, tcString

	-- * Getting types of literals
	, tyConOfLiteralFmt
	, typeOfLiteral
	, tyconOfLiteral )
where
import Shared.VarPrim
import DDC.Base.Literal
import DDC.Base.DataFormat
import DDC.Type.Exp
import DDC.Var
import Control.Monad


-- Kind Constructors ------------------------------------------------------------------------------
-- Atomic kind constructors.
kBox		= KCon KiConBox		SBox
kValue		= KCon KiConValue	SBox
kRegion		= KCon KiConRegion	SBox
kEffect		= KCon KiConEffect	SBox
kClosure	= KCon KiConClosure	SBox

-- Witness kind constructors.
kConst		= KCon KiConConst
		$ SFun kRegion  SProp

kDeepConst	= KCon KiConDeepConst
		$ SFun kValue   SProp

kMutable	= KCon KiConMutable
		$ SFun kRegion  SProp

kDeepMutable	= KCon KiConDeepMutable	
		$ SFun kValue   SProp

kLazy		= KCon KiConLazy
		$ SFun kRegion  SProp

kHeadLazy	= KCon KiConHeadLazy
		$ SFun kValue   SProp

kDirect		= KCon KiConDirect
		$ SFun kRegion  SProp

kPure		= KCon KiConPure
		$ SFun kEffect  SProp

kEmpty		= KCon KiConEmpty
		$ SFun kClosure SProp

-- Type Constructors -------------------------------------------------------------------------
tBot k		= TSum k	[]
tPure		= TSum kEffect  []
tEmpty		= TSum kClosure []


-- Effect type constructors
tRead		= TCon $ TyConEffect TyConEffectRead
		$ KFun kRegion kEffect

tDeepRead	= TCon $ TyConEffect TyConEffectDeepRead
		$ KFun kValue kEffect

tHeadRead	= TCon $ TyConEffect TyConEffectHeadRead
		$ KFun kValue kEffect

tWrite		= TCon $ TyConEffect TyConEffectWrite
		$ KFun kRegion kEffect

tDeepWrite	= TCon $ TyConEffect TyConEffectDeepWrite
		$ KFun kValue kEffect


-- Closure type constructors
tFree v		= TCon $ TyConClosure (TyConClosureFree v) 
		$ KFun kClosure kClosure

tFreeType v	= TCon $ TyConClosure (TyConClosureFreeType v) 
		$ KFun kValue kClosure

tFreeRegion v	= TCon $ TyConClosure (TyConClosureFreeRegion v) 
		$ KFun kRegion kClosure
		
tDanger 	= TCon $ TyConClosure TyConClosureDanger
		$ KFun kRegion (KFun kBox kClosure)


-- Witness type constructors 
tMkConst	= TCon $ TyConWitness TyConWitnessMkConst	
		$ KFun kRegion (KApp kConst		(TVar kRegion $ UIndex 0))

tMkDeepConst 	= TCon $ TyConWitness TyConWitnessMkDeepConst
		$ KFun kValue  (KApp kDeepConst		(TVar kRegion $ UIndex 0))

tMkMutable	= TCon $ TyConWitness TyConWitnessMkMutable
	 	$ KFun kRegion (KApp kMutable		(TVar kRegion $ UIndex 0))

tMkDeepMutable	= TCon $ TyConWitness TyConWitnessMkDeepMutable
 		$ KFun kValue  (KApp kDeepMutable	(TVar kRegion $ UIndex 0))

tMkLazy		= TCon $ TyConWitness TyConWitnessMkLazy
		$ KFun kRegion (KApp kLazy		(TVar kRegion $ UIndex 0))

tMkHeadLazy	= TCon $ TyConWitness TyConWitnessMkHeadLazy
		$ KFun kValue  (KApp kHeadLazy		(TVar kRegion $ UIndex 0))

tMkDirect	= TCon $ TyConWitness TyConWitnessMkDirect
		$ KFun kRegion (KApp kDirect		(TVar kRegion $ UIndex 0))

tMkPurify	= TCon $ TyConWitness TyConWitnessMkPurify	
		$ KFun kRegion 
			(KFun 	(KApp kConst (TVar kRegion $ UIndex 0))
				(KApp kPure  (TApp tRead (TVar kRegion $ UIndex 1))))

tMkPure		= TCon $ TyConWitness TyConWitnessMkPure
		$ KFun kEffect (KApp kPure (TVar kEffect $ UIndex 0))
		
-- Elaboration constructors
tElaborateRead  = TCon $ TyConElaborate TyConElaborateRead
		$ KFun kValue kValue

tElaborateWrite	= TCon $ TyConElaborate TyConElaborateWrite
		$ KFun kValue kValue

tElaborateModify = TCon $ TyConElaborate TyConElaborateModify
		$ KFun kValue kValue


-- | Get the type constructor for a bool of this format.
--	The format needs to be `Unboxed` or `Boxed`.
tcBool :: DataFormat -> Maybe TyCon
tcBool fmt
 = case fmt of
	Unboxed		-> Just $ TyConData (primTBool fmt) kValue Nothing
	Boxed		-> Just $ TyConData (primTBool fmt) (KFun kRegion kValue) Nothing
	_		-> Nothing
	
	
-- | Get the type constructor of a word of this format.
tcWord  :: DataFormat -> TyCon
tcWord 	= tcTyDataBits primTWord


-- | Get the type constructor of an int of this format.
tcInt   :: DataFormat -> TyCon
tcInt	= tcTyDataBits primTInt


-- | Get the type constructor of a float of this format.
tcFloat :: DataFormat -> TyCon
tcFloat	= tcTyDataBits primTFloat


-- | Get the type constructor of a char of this format.
tcChar  :: DataFormat -> TyCon
tcChar	= tcTyDataBits primTChar


-- | Make the type constructor of something of this format.
tcTyDataBits :: (DataFormat -> Var) -> DataFormat -> TyCon
tcTyDataBits mkVar fmt
 = case fmt of 
	Boxed		-> TyConData (mkVar fmt) (KFun kRegion kValue) Nothing
	BoxedBits _	-> TyConData (mkVar fmt) (KFun kRegion kValue) Nothing
	Unboxed		-> TyConData (mkVar fmt) kValue Nothing
	UnboxedBits _	-> TyConData (mkVar fmt) kValue Nothing
	

-- | Get the type constructor of a string of this format.
tcString :: DataFormat -> Maybe TyCon
tcString fmt
 = case fmt of
	Unboxed		-> Just $ TyConData (primTString fmt) (KFun kRegion kValue) Nothing
	Boxed		-> Just $ TyConData (primTString fmt) (KFun kRegion kValue) Nothing
	_		-> Nothing

-- | Get the type constructor used to represent some literal value
tyConOfLiteralFmt :: LiteralFmt -> Maybe TyCon
tyConOfLiteralFmt (LiteralFmt lit fmt)
 = case (lit, fmt) of
 	(LBool _, 	fmt')	-> tcBool   fmt'
	(LWord _, 	fmt')	-> Just $ tcWord   fmt'
	(LInt _,	fmt')	-> Just $ tcInt    fmt'
	(LFloat _,	fmt')	-> Just $ tcFloat  fmt'
	(LChar _,	fmt')	-> Just $ tcChar   fmt'
	(LString _,	fmt')	-> tcString fmt'


-- | Get the type associated with a literal value.
typeOfLiteral :: LiteralFmt -> Maybe Type
typeOfLiteral litfmt
	= liftM TCon (tyconOfLiteral litfmt)


-- | Get the type constructor associated with a literal value.
tyconOfLiteral :: LiteralFmt -> Maybe TyCon
tyconOfLiteral (LiteralFmt lit fmt)
 = case lit of
	LBool _		-> tcBool   fmt
	LWord _		-> Just $ tcWord   fmt
	LInt _		-> Just $ tcInt    fmt
	LFloat _	-> Just $ tcFloat  fmt
	LChar _		-> Just $ tcChar   fmt
	LString _	-> tcString fmt


