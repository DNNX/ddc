
-- | Handles parsing of pragmas in source language
--   BUGS: pragma parse errors are ugly

module Source.Pragma
	( Pragma (..)
	, slurpPragmaTree)
where

import qualified Shared.Var	as Var
import Source.Pretty
import Source.Exp
import Shared.Pretty
import Shared.Base
import Shared.Error
import Shared.Warning
import Shared.Literal
import Util

stage	= "Source.Pragma"

data Pragma
	= PragmaCCInclude	String

slurpPragmaTree tree
	= concat $ map slurpPragma tree

slurpPragma pp@(PPragma _ (XVar sp v : _))
	| Var.name v == "cc_includes"
	= slurp_ccIncludes pp

	| otherwise
	= warning (WarnUnknownPragma v) []

slurpPragma _	= []
	
	
-- cc_includes
-- 	Adds an include statement directly into the emitted C program. 
--	Good for getting the correct function prototypes in ffi code.
slurp_ccIncludes (PPragma _ xx@[XVar sp v, XList _ xStrs])
 = case sequence $ map slurpConstStr xStrs of
 	Just strs	-> map PragmaCCInclude strs
	Nothing		-> panic stage $ pprStrPlain $ "slurp_ccIncludes: bad arg " % xx
   

slurpConstStr :: Exp SourcePos -> Maybe String
slurpConstStr xx
 = case xx of
	XLit _ (LiteralFmt (LString str) fmt) 	-> Just str
	_					-> Nothing

