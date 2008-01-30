
module Type.Base
	( Class (..),	classInit
	, Graph (..),	graphInit
	
	, graphSize_init
	, graphSize_inc)
where

import Util
import Type.Exp
import Type.Pretty

import qualified Data.Map	as Map
import Data.Map 		(Map)

import qualified Data.Set	as Set
import Data.Set			(Set)

import Data.Array.IO



-- | A Node in the type graph
data Class 
	
	-- | An unallocated class
	= ClassNil						

	-- | Reference to another class.
	--	A Forward is to the resulting class when classes are merged.
	| ClassForward ClassId					

	-- | Some auxilliary constraint between classes.
	| ClassFetter
		{ classId		:: ClassId
		, classFetter		:: Fetter }

	-- | An equivalence class.
	| Class
		{ 	
		-- | An Id for this class

		  classId		:: ClassId	

		-- | Kind of this class.
		, classKind		:: Kind				

		-- | The name for this class.
		--	This is taken as one of the vars from the Nodes list, or generated fresh if none exists.
		, className		:: Maybe Var
	
		-- | The type of this class (if available)
		--	If there are constraints waiting to be unified this will be Nothing.
		, classType		:: Maybe Type

		-- | Type constraints waiting to be unified.
		, classQueue		:: [Type]

		-- | Fetters acting on this class
		--	Single parameter type class constraints are placed directly in this list, 
		--	while multi-parameter constraints are recored as a classId which points to
		--	the ClassFetter which holds the constraint.
		, classFetters		:: [Type]

		-- | Constraints that have been added to this class, including source information.
		, classNodes		:: [(Type, TypeSource)]		

		-- | Other classes which reference this one.
		, classBackRef		:: Set ClassId }		

	deriving (Show)


classInit cid kind
	= Class
	{ classId		= cid
	, classKind		= kind

	, className		= Nothing
	, classType		= Nothing
	, classQueue		= []
	, classNodes		= []
	, classFetters		= []
	
	, classBackRef		= Set.empty }
		

-- | The Type Graph.
data Graph
	= Graph { 
		-- | The classes
		graphClass		:: IOArray ClassId Class		

		-- | Generator for new ClassIds.
		, graphClassIdGen	:: !Int					

		-- | Type Var -> ClassId Map.
		, graphVarToClassId	:: Map Var ClassId

		-- | The classes which are active, 
		--	ie waiting to be unified or crushed.
		, graphActive		:: Set ClassId }	
					

-- | Initial size of the graph.
graphSize_init	= (5000 :: Int)

-- | Size to increase the graph by when it fills up.
graphSize_inc	= (5000 :: Int)

graphInit :: IO Graph
graphInit
 = do
	class1		<- newArray (ClassId 0, ClassId graphSize_init) ClassNil
 	return	Graph
		{ graphClass		= class1
		, graphClassIdGen	= 0
		, graphVarToClassId	= Map.empty 
		, graphActive		= Set.empty }





