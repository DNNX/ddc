
module DDC.Driver.Command.Flow.Lower
        (cmdFlowLower)
where
import DDC.Driver.Stage
import DDC.Driver.Source
import DDC.Build.Pipeline
import Control.Monad.Trans.Error
import Control.Monad.IO.Class
import qualified DDC.Base.Pretty                        as P


-- | Lower a flow program to loop code.
cmdFlowLower
        :: Config
        -> Source       -- ^ Source of the code.
        -> String       -- ^ Program module text.
        -> ErrorT String IO ()

cmdFlowLower config source sourceText
 = do   
        errs    <- liftIO
                $  pipeText (nameOfSource source)
                            (lineStartOfSource source)
                            sourceText
                $  stageFlowLoad  config source
                [  stageFlowPrep  config source
                [  stageFlowLower config source
                [  PipeCoreOutput SinkStdout ]]]

        case errs of
         []     -> return ()
         es     -> throwError $ P.renderIndent $ P.vcat $ map P.ppr es
