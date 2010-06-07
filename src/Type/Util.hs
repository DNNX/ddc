module Type.Util
	( module Type.Util.Bits
	, module Type.Util.Instantiate
	, module Type.Util.Normalise
	, module Type.Util.Mask
	, module Type.Util.Trim
	, makeOpTypeT
	, makeTVar 
	, makeTWhere
	, slurpVarsRD)
	
where
import Type.Util.Bits
import Type.Util.Instantiate
import Type.Util.Normalise
import Type.Util.Mask
import Type.Util.Trim
import Shared.VarPrim
import Util
import DDC.Main.Error
import DDC.Main.Pretty
import DDC.Type.Exp
import DDC.Type.Builtin
import DDC.Type.Compounds
import DDC.Type.Kind
import DDC.Var
import qualified Debug.Trace

stage	= "Type.Util"
debug	= False
trace ss xx
 = if debug 
 	then Debug.Trace.trace (pprStrPlain ss) xx
	else xx

-- | Make an operational type.
makeOpTypeT :: Type -> Maybe Type
makeOpTypeT tt
 = trace ("makeOpTypeT " % show tt)
 $ case tt of
 	TForall v k t		-> makeOpTypeT t
	TFetters t fs		-> makeOpTypeT t

	TCon{}
	 | Just (v, k, ts)	<- takeTData tt
	 -> makeOpTypeData tt

	TApp (TCon TyConElaborate{}) t2
	 -> makeOpTypeT t2

	TApp{}
	 | Just (t1, t2, eff, clo) <- takeTFun tt
	 , Just t1'		<- makeOpTypeT2 t1
	 , Just t2'		<- makeOpTypeT  t2
	 -> Just $ makeTFun t1' t2' tPure tEmpty
	 
	 | Just (v, k, ts)	<- takeTData tt
	 -> makeOpTypeData tt

	TVar{}			-> Just $ makeTData primTObj kValue []

	_			-> freakout stage
					("makeOpTypeT: can't make operational type from " %  show tt)
					Nothing
makeOpTypeT2 tt
 = trace ("makeOpTypeT2 " % show tt)
 $ case tt of
 	TForall v k t		-> makeOpTypeT2 t
	TFetters t fs		-> makeOpTypeT2 t
	TVar{}			-> Just $ makeTData primTObj kValue []

	TCon{}
	 | Just (v, k, ts)	<- takeTData tt
	 -> makeOpTypeData tt

	TApp (TCon TyConElaborate{}) t2
	 -> makeOpTypeT t2

	TApp{}
	 | Just (t1, t2, eff, clo)	<- takeTFun tt
	 -> Just $ makeTData primTThunk kValue []
	
	 | Just (v, k, ts)	<- takeTData tt
	 -> makeOpTypeData tt

	_			-> freakout stage
					("makeOpTypeT2: can't make operational type from " % show tt)
					Nothing

makeOpTypeData tt
	| Just (v, k, ts)	<- takeTData tt
	, last (varName v) == '#'
	= case (sequence $ (map makeOpTypeT [t | t <- ts, isValueType t])) of
		Just ts'	-> Just $ makeTData v kValue ts'
		_		-> Nothing
	
	| Just (v, k, ts)	<- takeTData tt
	= Just $ makeTData primTObj kValue []

makeOpTypeData _	= Nothing


-- | Make a TVar, using the namespace of the var to determine it's kind
makeTVar :: Var -> Type
makeTVar v	
 = let Just k	= defaultKindOfVar v
   in	TVar k (UVar v)


-- | Add some where fetters to this type
makeTWhere ::	Type	-> [(Var, Type)] -> Type
makeTWhere	t []	= t
makeTWhere	t vts	
	= TFetters t 
	$ [ FWhere (TVar k $ UVar v) t'
		| (v, t')	<- vts
		, let Just k	= defaultKindOfVar v ]


-- Slurping ----------------------------------------------------------------------------------------
-- | Slurp out the region and data vars present in this type
--	Used for crushing ReadT, ConstT and friends
slurpVarsRD
	:: Type 
	-> ( [Region]	-- region vars and cids
	   , [Data])	-- data vars and cids

slurpVarsRD tt
 	= slurpVarsRD_split [] [] 
	$ slurpVarsRD' tt

slurpVarsRD_split rs ds []	= (rs, ds)
slurpVarsRD_split rs ds (t:ts)
 = case t of
 	TVar	k _	| k == kRegion	-> slurpVarsRD_split (t : rs) ds ts
 	TVar	k _	| k == kValue	-> slurpVarsRD_split rs (t : ds) ts	
	_				-> slurpVarsRD_split rs ds ts
	
slurpVarsRD' tt
	| TFetters t f	<- tt
	= slurpVarsRD' t

	| TApp{}	<- tt
	, Just (v, k, ts)	<- takeTData tt
	= catMap slurpVarsRD' ts
	
	| TApp{}	<- tt
	, Just _		<- takeTFun tt
	= []
	
	| TApp t1 t2	<- tt
	= slurpVarsRD' t1 ++ slurpVarsRD' t2

	| TSum{}	<- tt	= []
	| TCon{}	<- tt	= []

	| TVar k _	<- tt
	= if k == kRegion || k == kValue
		then [tt]
		else []
				
	| TError{}	<- tt	= []

	| otherwise
	= panic stage
	$  "slurpVarsRD: no match for " % tt



