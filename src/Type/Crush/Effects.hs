-- | Crush effects into their parts.

module Type.Crush.Effects
	( crushEffectC )
where

import Util

import qualified Data.Set	as Set
import Data.Set			(Set)

import qualified Data.Map	as Map
import Data.Map			(Map)

import qualified Shared.Var	as Var
import qualified Shared.VarBind	as Var
import Shared.VarPrim
import Shared.Var		(VarBind, NameSpace(..))
import Shared.Error

import Type.Exp
import Type.Util
import Type.State
import Type.Class
import Type.Feed
import Type.Trace
import Type.Pretty
import Type.Util.Pack

import Type.Crush.Unify

import Type.Plate.Collect	(collectClassIds)
import Type.Plate.Trans

-----
debug	= True
trace s	= when debug $ traceM s
stage	= "Type.Squid.Crush"

-- Try and crush the effect in this node.
crushEffectC :: ClassId -> SquidM ()
crushEffectC cid
 = do	
	eLoad		<- loadEffect cid

 	trace	$ "\n"
		% "*   crushEffectC " 	% cid		% "\n"
		% "    eLoad       = " 	% eLoad		% "\n"

	eCrushed	<- transformTM crushEffectT eLoad

	trace	$ "    eCrushed    = "	% eCrushed 	% "\n"
	
	if eCrushed /= eLoad
	 then do	
		-- update the class queue with the new effect
		Just c	<- lookupClass cid
	 	updateClass cid
			c { classType = eCrushed }
			
		-- For the classIds in the new effect, update the backrefs to point
		--	to this class.
		let classIds	= collectClassIds eCrushed
		mapM_ (\cid' -> addBackRef cid' cid) classIds

		-- update the register
		mapM_ (\e -> unregisterClass e cid)
			$ map (\t -> case t of 
					TEffect ve _ 	-> Var.bind ve
					_		-> panic stage $ "crushEffectC: eLoad = " % eLoad)
			$ flattenTSum eLoad

		registerNodeT cid eCrushed
		return ()

	 else	return ()


-- Try and crush this effect into parts.
crushEffectT :: Effect -> SquidM Effect
crushEffectT tt

	-- Read of outer constructor of object.
	| TEffect ve [t1]	<- tt
	, Var.bind ve == Var.EReadH
	= do	case t1 of
		 TData v (tR : ts)	-> return $ TEffect primRead [tR]
		 _			-> return $ tt
	

	-- Read of whole object. (deep read).
	| TEffect ve [t1]	<- tt
	, Var.bind ve == Var.EReadT
	= do	
		let bits	= slurpDataRT t1
		let esRegion	= map (TEffect primRead)
				$ (  [[r] | r@(TVar KRegion _)		<- bits]
				  ++ [[r] | r@(TClass KRegion _)	<- bits])


		let esType	= map (TEffect primReadT)
				$ (  [[t] | t@(TVar KData _)	<- bits]
				  ++ [[t] | t@(TClass KData _)	<- bits])

	  	return	$ makeTSum KEffect 
			$ (esRegion ++ esType)


	-- Write of whole object. (deep write)
	| TEffect ve [t1]	<- tt
	, Var.bind ve == Var.EWriteT
	= do	
		let bits	= slurpDataRT t1
		let esRegion	= map (TEffect primWrite)
				$ (  [[r] | r@(TVar KRegion _)		<- bits]
				  ++ [[r] | r@(TClass KRegion _)	<- bits])


		let esType	= map (TEffect primWriteT)
				$ (  [[t] | t@(TVar KData _)	<- bits]
				  ++ [[t] | t@(TClass KData _)	<- bits])
				
	  	return	$ makeTSum KEffect 
			$ (esRegion ++ esType)


	-- can't crush this one
	| otherwise
	= return $ tt


-- | Load in the effect for this cid.
loadEffect :: ClassId -> SquidM Type
loadEffect cid
 = do	Just c		<- lookupClass cid
 	let tNode	= classType c

	tPacked		<- liftM packType $ loadType tNode

	let es		= map (\e -> case e of
				TEffect v ts	-> TEffect v (map (fst . stripFettersT) ts)
				_		-> e)
			$ flattenTSum tPacked

	return		$ makeTSum KEffect es


-- | Load in nodes for every cid in this type.
loadType :: Type -> SquidM Type
loadType tt	= transformTM loadType' tt

loadType' tt
 = case tt of
 	TClass k cid	-> traceType cid
	_ 		-> return tt
	
	 
-- | Slurp out components of this type which are interesting to !ReadT \/ !WriteT
slurpDataRT :: Type -> [Type]
slurpDataRT tt
 = case tt of
	TFun{}			-> []
 	TData v ts		-> catMap slurpDataRT ts

	TVar KRegion _		-> [tt]
	TVar KData   _		-> [tt]
	TVar _  _		-> []
	
	TClass KRegion _	-> [tt]	
	TClass KData   _	-> [tt]
	TClass _ _		-> []

	TFetters fs t		-> slurpDataRT t

	_ 	-> panic stage
		$  "slurpDataRT: no match for " % tt % "\n"


