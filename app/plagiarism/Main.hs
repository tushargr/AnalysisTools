import Lichen.Config.Languages
import Lichen.Config.Plagiarism
import Lichen.Plagiarism.Main

main :: IO ()
main = run $ defaultConfig { language = langC }
