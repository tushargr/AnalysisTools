module Lichen.Parser where

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

data Tag = Tag T.Text | TagData T.Text T.Text deriving (Show, Eq)

hasTag :: T.Text -> Node -> Bool
hasTag t (Node ts _) = Tag t `elem` ts
hasTag _ _ = False

countTag :: T.Text -> Node -> Integer
countTag t n@(Node _ ns) = (if hasTag t n then 1 else 0) + sum (countTag t <$> ns)
countTag _ _ = 0
