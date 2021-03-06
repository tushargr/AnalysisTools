module Lichen.Plagiarism.Winnow ( fingerprints
                                ) where

import Data.Hashable
import qualified Data.List.NonEmpty as NE

import Lichen.Lexer
import Lichen.Plagiarism.Submitty

-- Produce a list by sliding a window of size k over the list lst.
windows :: Int -> [a] -> Maybe [NE.NonEmpty a]
windows _ [] = Nothing
windows k lst@(_:xs) | k <= 0 = Nothing
                     | length lst >= k = case windows k xs of
                                             Just ws -> (:ws) <$> NE.nonEmpty (take k lst)
                                             Nothing -> (:[]) <$> NE.nonEmpty (take k lst)
                     | otherwise = Nothing

hashWin :: Hashable a => NE.NonEmpty (Tagged a) -> Fingerprint
hashWin l = Tagged (hash . fmap tdata $ l) (spanPos . fmap tpos $ l) where
    spanPos lst = TokPos (startLine $ NE.head lst) (endLine $ NE.last lst) (startCol $ NE.head lst) (endCol $ NE.last lst)

-- Given a token sequence, generate the fingerprints of that sequence.
fingerprint :: Hashable a => Int -> [Tagged a] -> [Fingerprint]
fingerprint k lst = case windows k lst of
                        Just ws -> hashWin <$> ws
                        Nothing -> []

-- Given the fingerprints of some data, selectively prune those
-- fingerprints to improve efficiency. This process is detailed in
--     http://theory.stanford.edu/~aiken/publications/papers/sigmod03.pdf,
-- but as a brief summary:
-- The algorithm is reliant on two user-provided values: t, or the
-- guarantee threshold, and k (previously used in the fingerprint
-- function), the noise threshould. k marks the character (or, in more
-- complex cases, token) length below which matches are considered noise.
-- t marks the character length above which we want to definitely detect
-- all matches. In other words, to quote the previously listed paper:
--     1) If there is a substring match at least as long as the guarantee
--     threshold t, then this match is detected, and
--     2) We do not detect any matches shorter than the noise threshold k
-- Using t and k, a window size is determined to be t - k + 1. This value
-- is used to move a sliding window over the fingerprints, a process
-- mirroring that used to break the initial data into k-grams. Within each
-- window, the minimum value is taken and added to a result set, if this
-- particular instance is not already in the result set. For example, take
-- two windows
--     [2 1 3 4] and [1 3 4 5],
-- which are windows over the sequence
--     [2 1 3 4 5].
-- In this situation, the hash 1 is added to the result set when examining
-- the first window. When the second window is examined, the minimum value
-- is 1, but it is the same 1 that was already added to the result set, so
-- it is ignored and no value is added. However, say the windows are
--     [2 1 3 4] and [1 3 4 1],
-- over the sequence
--     [2 1 3 4 1].
-- Here, 1 is added once when processing the first window, but in the
-- second window another 1 is added to the result set, since there is
-- a minimum value present that was not already processed.
winnow :: Int -> Int -> [Fingerprint] -> [Fingerprint]
winnow t k lst = go [] allWindows where
    allWindows :: [[(Fingerprint, Int)]]
    allWindows = case windows (t - k + 1) $ zip lst [1, 2 ..] of Just ws -> NE.toList <$> ws; Nothing -> []
    go :: [(Fingerprint, Int)] -> [[(Fingerprint, Int)]] -> [Fingerprint]
    go acc [] = fst <$> acc
    go acc (w:ws) =
        let uz = unzip acc
            fil = filter (\(_, n) -> notElem n $ snd uz) w in
                if null fil
                    then go acc ws
                    else let mf = minimum fil
                             mo = minimum w in
                                 if mf == mo then go (minimum fil:acc) ws
                                             else go acc ws

fingerprints :: Hashable a => Int -> Int -> [Tagged a] -> [Fingerprint]
fingerprints signal noise = winnow signal noise . fingerprint noise
