module Lichen.Config.CountToken where

import Lichen.Config
import Lichen.Config.Languages

data Config = Config
            { language :: Language
            , token :: Maybe String
            , sourceFile :: Maybe FilePath
            }

defaultConfig :: Config
defaultConfig = Config { language = langDummy
                       , token = Nothing
                       , sourceFile = Nothing
                       }

type CountToken = Configured Config
