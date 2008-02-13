{-# OPTIONS -fwarn-unused-imports #-}

module Type.Scheme
	( extractType
	, generaliseType 
	, watchClass)
where

import Type.Exp
import Type.Pretty
import Type.Plate
import Type.Util
import Type.Trace
import Type.Error

import Type.Check.GraphicalData
import Type.Check.Soundness

import Type.Effect.MaskLocal
-- import Type.Effect.MaskFresh	(maskEsFreshT)
-- import Type.Effect.MaskPure	(maskEsPureT)

import Type.State
import Type.Class
import Type.Plug		
import Type.Port
import Type.Context
import Type.Util

import Shared.Error
import qualified Shared.Var	as Var
import qualified Shared.VarUtil	as Var
import Shared.Var		(NameSpace(..))
import Shared.VarPrim

import qualified Main.Arg	as Arg

import qualified Data.Map	as Map
import qualified Data.Set	as Set
import Data.Set			(Set)

import Util



-----
stage	= "Type.Scheme"
debug	= True
trace s	= when debug $ traceM s

watchClass src code
 = do	mC	<- lookupClass (ClassId code)
 
 	let res
		| Just Class 
			{ classType	= mType
			, classQueue 	= queue  	
			, classNodes	= nodes		}	<- mC
			
		= trace ( "--- class " % code % "----------------------\n"
			% "--  src   = " % src			% "\n"
			% "--  type  = " % mType		% "\n"
			% "--  queue = " % queue		% "\n"
			% "--  nodes = " % (map fst nodes)	% "\n\n")

		| otherwise
		= return ()
	res


-- | Extract a type from the graph and pack it into standard form.
--	BUGS: we need to add fetters from higher up which are acting on this type.

extractType 
	:: Bool 		-- whether to treat effect and closure vars that were never quantified as TBot
	-> Var 			-- var of type to extract
	-> SquidM (Maybe Type)

extractType final varT
 = do	defs		<- gets stateDefs
	varT'		<- sinkVar varT
	quantKinds	<- gets stateQuantifiedVars

	trace	$ "*** Scheme.extractType " % varT % "\n"
		% "\n"

	let result
		-- if this var is in the defs table then return that type
		| Just tt		<- Map.lookup varT defs
		= do	trace 	$ "    def: " %> prettyTS tt % "\n"
			return $ Just tt
		
		-- if this is a quantified tyvar then there's nothing to do
		--	(this can happen during Type.Export)
		| Just (k, Nothing)	<- Map.lookup varT' quantKinds
		= do	let tt	= TVar k varT'
			trace 	$ "    quant: " %> prettyTS tt % "\n"
			return	$ Just tt 

		| Just (k, Just tMore)	<- Map.lookup varT' quantKinds
		= do	let tt	= (TFetters [FMore (TVar k varT') tMore] (TVar k varT'))
			trace 	$ "    quantMore: " %> prettyTS tt % "\n"
			return $ Just tt
		
		-- otherwise extract it from the graph
		| otherwise
		= {-# SCC "extractType" #-} extractType' final varT
		
	result
	

extractType' final varT
 = do	mCid	<- lookupVarToClassId varT

	case mCid of
	 Nothing	
	  -> do	graph			<- gets stateGraph
	  	let varToClassId	=  graphVarToClassId graph
	  	freakout stage
		 	("extractType: no classId defined for variable " % (varT, Var.bind varT)		% "\n"
			% " visible vars = " % (map (\v -> (v, Var.bind v)) $ Map.keys varToClassId)		% "\n")
			$ return Nothing

	 Just cid	-> extractTypeC final varT cid
	 
extractTypeC final varT cid
 = do 	
	
 	tTrace	<- liftM sortFsT 	
		$ {-# SCC "extract/trace" #-} 
		  traceType cid

	trace	$ "    tTrace           =\n" %> prettyTS tTrace	% "\n\n"

	-- Check if the data portion of the type is graphical.
	--	If it is then it'll hang packType when it tries to construct an infinite type.
	let cidsDataLoop	
		= checkGraphicalDataT tTrace

	trace	$ "    cidsDataLoop     = " % cidsDataLoop % "\n\n"

	
	if (isNil cidsDataLoop)
	 -- no graphical data, ok to continue.
	 then extractTypeC1 final varT cid tTrace

	 -- we've got graphical data, add an error to the solver state and bail out.
	 else do
	 	addErrors [ErrorInfiniteTypeClassId {
	 			eClassId	= head cidsDataLoop }]

		return $ Just $ TError KData [tTrace]

extractTypeC1 final varT cid tTrace
 = do	
	-- Cut loops through the effect and closure portions of this type
	let tCutLoops	
		= {-# SCC "extract/cut" #-} 
		  cutLoopsT tTrace

	trace	$ "    tCutLoops        =\n" %> prettyTS tCutLoops % "\n\n"

	-- Pack type into standard form
	let tPack	
		= {-# SCC "extract/pack" #-} 
		  packType tCutLoops

	trace	$ "    tPack            =\n" %> prettyTS tPack % "\n\n"

	-- Trim closures
	let tTrim	= 
		case kindOfType tPack of
			KClosure	-> trimClosureC Set.empty tPack
			_		-> trimClosureT Set.empty tPack

	trace	$ "    tTrim            =\n" %> prettyTS tTrim % "\n\n"

	let tTrimPack	
		= {-# SCC "extract/pack_trim" #-}
		  packType tTrim

	trace	$ "    tTrimPack        =\n" %> prettyTS tTrimPack % "\n\n"


	extractType_final final varT cid tTrimPack
	

extractType_final True varT cid tTrim
 = do	
 	-- plug classIds with vars
 	tPlug		<- plugClassIds [] tTrim
 
	-- close off never-quantified effect and closure vars
 	quantVars	<- gets stateQuantifiedVars
 	let tFinal	=  finaliseT quantVars tPlug
	
	trace	$ "    tFinal          =\n" %> prettyTS tFinal	% "\n\n"
	extractTypeC2 varT cid tFinal
	
extractType_final False varT cid tTrim
	= extractTypeC2 varT cid tTrim

extractTypeC2 varT cid tFinal
 = do	
	-- Reduce context
	classInst	<- gets stateClassInst

	let tReduced	
		= {-# SCC "extract/redude" #-}
		  reduceContextT classInst tFinal

	trace	$ "    tReduced         =\n" %> prettyTS tReduced % "\n\n"

	return	$ Just tReduced
	


-- | Generalise a type
--
generaliseType
	:: Var 			-- binding variable of the type being generalised
	-> Type			-- the type to generalise
	-> Set ClassId		-- the classIds which must remain fixed (non general)
	-> SquidM Type

generaliseType varT tCore envCids
 = {-# SCC "generaliseType" #-} generaliseType' varT tCore envCids 

generaliseType' varT tCore envCids
 = do
	args			<- gets stateArgs
	trace	$ "*** Scheme.generaliseType " % varT % "\n"
		% "\n"
		% "    tCore\n"
		%> prettyTS tCore	% "\n\n"

		% "    envCids          = " % envCids		% "\n"
		% "\n"

	-- work out what effect and closure vars are in contra-variant branches
	let contraTs	= catMaybes
			$ map (\t -> case t of
					TClass KEffect cid	-> Just t
					TClass KClosure cid	-> Just t
					_			-> Nothing)
			$ slurpContraClassVarsT tCore
	
	let tMore	= moreifyFettersT (Set.fromList contraTs) tCore
	
	trace	$ "    contraTs = " % contraTs	% "\n"

	trace	$ "    tMore\n"
		%> prettyTS tMore	% "\n\n"


	-- flatten out the scheme so its easier for staticRs.. to deal with
	let tFlat	= flattenT tMore
	trace	$ "    tFlat\n"
		%> prettyTS tFlat	% "\n\n"

	-- Work out which cids can't be generalised in this type.

	-- 	Can't generalise regions in non-functions.
	--	... some data object is in the same region every time you use it.
	--
	let staticRsData 	= Set.toList $ staticRsDataT	tFlat
	let staticRsClosure 	= Set.toList $ staticRsClosureT	tFlat

	trace	$ "    staticRsData     = " % staticRsData	% "\n"
		% "    staticRsClosure  = " % staticRsClosure	% "\n"


	--	Can't generalise cids which are under mutable constructors.
	--	... if we generalise these classes then we could update an object at one 
	--		type and read it at another, violating soundness.
	--	
	let staticDanger	= if Set.member Arg.GenDangerousVars args
					then []
					else dangerousCidsT tMore

	trace	$ "    staticDanger     = " % staticDanger	% "\n"

	-- These are all the cids we can't generalise
	let staticCids		= Set.toList envCids ++ staticRsData ++ staticRsClosure ++ staticDanger

	-- Rewrite non-static cids to the var for their equivalence class.
	tPlug			<- plugClassIds staticCids tMore

	trace	$ "    staticCids       = " % staticCids	% "\n\n"
		% "    tPlug\n"
		%> prettyTS tPlug 	% "\n\n"

	-- Clean empty effect classes that aren't ports.
	-- 	BUGS: don't clean variables in the type environment.
	--	TODO we have to do a reduceContext again to pick up (Pure TBot) 
	--	.. the TBot won't show up until we do the cleaning. Won't need this 
	--	once we can discharge these during the grind. It's duplicated in extractType above
	classInst	<- gets stateClassInst

	let tClean	= reduceContextT classInst 
			$ cleanType Set.empty tPlug

	trace	$ "    tClean\n" 
			%> ("= " % prettyTS tClean)		% "\n\n"

	-- Check context for problems.
	checkContext tClean

	-- Mask effects and CMDL constraints on local regions.
	-- 	Do this before adding foralls so we don't end up with quantified regions which
	--	aren't present in the type scheme.
	--
	let rsVisible	= visibleRsT $ flattenT tClean
	let tMskLocal	= maskLocalT rsVisible tClean

	trace	$ "    rsVisible    = " % rsVisible		% "\n\n"
	trace	$ "    tMskLocal\n"
		%> prettyTS tMskLocal 	% "\n\n"


	-- Quantify free variables.
	let vsFree	= filter (\v -> not $ Var.nameSpace v == NameValue)
			$ filter (\v -> not $ Var.isCtorName v)
			$ Var.sortForallVars
			$ Set.toList $ freeVars tMskLocal

	let vksFree	= map 	 (\v -> (v, kindOfSpace $ Var.nameSpace v)) 
			$ vsFree

	trace	$ "    vksFree   = " % vksFree	% "\n\n"
	let tScheme	= quantifyVarsT vksFree tMskLocal

	-- Remember which vars are quantified
	--	we can use this information later to clean out non-port effect and closure vars
	--	once the solver is done.
	let vtsMore	= Map.fromList 
			$ [(v, t)	| FMore (TVar k v) t
					<- slurpFetters tScheme]
	
	-- lookup :> bounds for each quantified var
	let vkbsFree	= map (\(v, k) -> (v, (k, Map.lookup v vtsMore))) vksFree

	modify $ \s -> s { stateQuantifiedVars	
				= Map.unions
					[ Map.fromList vkbsFree
					, stateQuantifiedVars s ] }
		
	
	trace	$ "    tScheme\n"
		%> prettyTS tScheme 	% "\n\n"

	return	tScheme


slurpFetters tt
	= case tt of
		TForall vks t'	-> slurpFetters t'
		TFetters fs _	-> fs
		_		-> []


{-
	-- Mask effects on local and fresh regions
	let tMskFresh		= maskEsFreshT tMskLocal
	let tMskPure		= maskEsPureT  tMskFresh

	let tPack		= packType tMskPure


	-- Check the scheme against any available type signature.
	schemeSig	<- gets stateSchemeSig
	let mSig	= (Map.lookup varT schemeSig) :: Maybe Type
	let errsSig	= case mSig of
				Nothing		-> []
				Just sig	-> checkSig varT sig varT tPack
	addErrors errsSig
-}


-- | Empty effect and closure eq-classes which do not appear in the environment or 
--	a contra-variant position in the type can never be anything but _|_,
--	so we can safely erase them now.
--
--   TODO:
--	We need to run the cleaner twice to handle types like this:
--		a -(!e1)> b
--		:- !e1 = !{ !e2 .. !en }
--
--	where all of !e1 .. !en are cleanable.
--	Are two passes enough?
--	
cleanType :: Set Var -> Type -> Type
cleanType save tt
	= cleanType' save $ cleanType' save  tt

cleanType' save tt
 = let	vsFree	= Set.toList $ freeVars tt

	vsPorts	
		= catMaybes
		$ map (\t -> case t of 
			TVar k v	-> Just v
			_		-> Nothing)
		$ portTypesT tt

	vsClean	= [ v 	| v <- vsFree
			, elem (Var.nameSpace v) [Var.NameEffect, Var.NameClosure]
			, not $ Var.isCtorName v 
			, not $ elem v vsPorts 
			, not $ Set.member v save]

	sub	= Map.fromList
		$ map (\v -> (v, TBot (kindOfSpace $ Var.nameSpace v)))
		$ vsClean 

	tClean	= packType 
		$ substituteVT sub tt
	
   in	tClean



-- | After reducing the context of a type to be generalised, if certain constraints
--	remain then this is symptomatic of problems in the source program.
-- 
--	Projection constraints indicate an ambiguous projection.
--	Shape constraints indicate 
--	Type class constraints indicate that no instance for this type is available.
--
checkContext :: Type -> SquidM ()
checkContext tt
 = case tt of
 	TFetters fs t	-> mapM_ checkContextF fs
	_		-> return ()
 
checkContextF ff
 = case ff of
 	FProj j vInst tDict tBind
	 -> addErrors
	 	[ ErrorAmbiguousProjection
			{ eProj		= j } ]

	FConstraint vClass ts
	 | not 	$ elem vClass
	 	[ primMutable,	primMutableT
		, primConst,	primConstT
		, primLazy, 	primDirect
		, primPure,	primLazyH ]
	 -> addErrors
	 	[ ErrorNoInstance
			{ eClassVar		= vClass
			, eTypeArgs		= ts } ]
		
	_ -> return ()
	
