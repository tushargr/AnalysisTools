{-# LANGUAGE OverloadedStrings #-}

module Lichen.Plagiarism.Main where

import System.IO
import System.Environment
import System.Directory
import System.FilePath

import Data.Semigroup ((<>))

import Control.Monad.Reader
import Control.Monad.Except

import Options.Applicative

import qualified Config.Dyre as Dyre

import Lichen.Error
import Lichen.Config
import Lichen.Config.Languages
import Lichen.Config.Plagiarism
import Lichen.Plagiarism.Concatenate
import Lichen.Plagiarism.Highlight
import Lichen.Plagiarism.Walk
import Lichen.Plagiarism.Compare

parseOptions :: Config -> Parser Config
parseOptions dc = Config
               <$> strOption (long "datadir" <> short 'd' <> metavar "DIR" <> showDefault <> value (dataDir dc) <> help "Directory to store internal data")
               <*> strOption (long "concatdir" <> short 'c' <> metavar "DIR" <> showDefault <> value (concatDir dc) <> help "Subdirectory of data directory storing concatenated student code")
               <*> strOption (long "highlightdir" <> short 'i' <> metavar "DIR" <> showDefault <> value (highlightDir dc) <> help "Subdirectory of data directory storing syntax-highlighted student code")
               <*> (maybeDefault (sourceDir dc) <$> (optional . strOption $ long "sourcedir" <> short 's' <> metavar "DIR" <> help "Assignment directory containing user directories"))
               <*> (languageChoice (language dc) <$> (optional . strOption $ long "language" <> short 'l' <> metavar "LANG" <> help "Language of student code"))
    where maybeDefault :: Maybe a -> Maybe a -> Maybe a
          maybeDefault _ x@(Just _) = x
          maybeDefault x Nothing = x

realMain :: Config -> IO ()
realMain c = do
        options <- liftIO $ execParser opts
        flip runConfigured options $ do
            config <- ask
            base <- liftIO $ getEnv "LICHEN_CWD"
            p <- case sourceDir config of Just d -> return d; Nothing -> throwError $ InvocationError "No directory specified"
            dir <- liftIO $ canonicalizePath (base </> p)
            concatenate base dir
            highlight base dir
            prints <- fingerprintDir (language config) (base </> dataDir config </> concatDir config ++ dir)
            liftIO . print $ crossCompare prints
    where opts = info (helper <*> parseOptions c) (fullDesc <> progDesc "Run plagiarism detection" <> header "lichen-plagiarism - plagiarism detection")

run :: Config -> IO ()
run = Dyre.wrapMain $ Dyre.defaultParams
    { Dyre.projectName = "lichen-plagiarism"
    , Dyre.realMain = realMain
    , Dyre.statusOut = hPutStrLn stderr
    , Dyre.configDir = Just $ getEnv "LICHEN_CWD"
    , Dyre.cacheDir = Just $ (</>) <$> getEnv "LICHEN_CWD" <*> pure ".lichen/cache"
    }
