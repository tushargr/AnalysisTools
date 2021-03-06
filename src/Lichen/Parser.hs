{-# LANGUAGE OverloadedStrings #-}

module Lichen.Parser where

import Data.Aeson
import qualified Data.Text as T
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as BS.C8

import Lichen.Error

type Parser a = FilePath -> BS.ByteString -> Erring a

data Node = Node [Tag] [Node]
          | MetaCount Int
          | MetaIdent T.Text
          | DataInt Integer
          | DataFloat Double
          | DataBool Bool
          | DataStr T.Text
          | DataBytes BS.C8.ByteString
          deriving (Show, Eq)

instance ToJSON Node where
    toJSON (Node ts ns) = object [ "type" .= ("node" :: T.Text)
                                 , "tags" .= (toJSON <$> ts)
                                 , "children" .= (toJSON <$> ns)
                                 ]
    toJSON (MetaCount d) = object [ "type" .= ("meta_count" :: T.Text)
                                  , "data" .= d
                                  ]
    toJSON (MetaIdent d) = object [ "type" .= ("metadata_identifier" :: T.Text)
                                  , "data" .= d
                                  ]
    toJSON (DataInt d) = object [ "type" .= ("data_int" :: T.Text)
                                , "data" .= d
                                ]
    toJSON (DataFloat d) = object [ "type" .= ("data_float" :: T.Text)
                                  , "data" .= d
                                  ]
    toJSON (DataBool d) = object [ "type" .= ("data_bool" :: T.Text)
                                 , "data" .= d
                                 ]
    toJSON (DataStr d) = object [ "type" .= ("data_str" :: T.Text)
                                , "data" .= d
                                ]
    toJSON (DataBytes d) = object [ "type" .= ("data_bytes" :: T.Text)
                                  , "data" .= show d
                                  ]

newtype Tag = Tag T.Text deriving (Show, Eq)

instance ToJSON Tag where
    toJSON (Tag x) = toJSON x

hasTag :: T.Text -> Node -> Bool
hasTag t (Node ts _) = Tag t `elem` ts
hasTag _ _ = False

countTag :: T.Text -> Node -> Integer
countTag t n@(Node _ ns) = (if hasTag t n then 1 else 0) + sum (countTag t <$> ns)
countTag _ _ = 0

identChild :: T.Text -> Node -> Bool
identChild t (Node _ ns) = or (identChild t <$> ns)
identChild t (MetaIdent t') = t == t'
identChild _ _ = False

countCall :: T.Text -> Node -> Integer
countCall t n@(Node _ ns) = (if hasTag "call" n then case ns of (f:_) -> if identChild t f then 1 else 0; _ -> 0 else 0) + sum (countCall t <$> ns)
countCall _ _ = 0

countDepth :: T.Text -> Node -> Integer
countDepth t n@(Node _ ns) = (if hasTag t n then 1 else 0) + maximum (0:(countDepth t <$> ns))
countDepth _ _ = 0
