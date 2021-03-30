module Language.Adder.Parser ( parse, parseFile ) where

import           Control.Monad (void)
import           Text.Megaparsec hiding (parse)
-- import           Text.Megaparsec.String -- input stream is of type ‘String’
import           Text.Megaparsec.Char
import qualified Text.Megaparsec.Char.Lexer as L
import           Text.PrettyPrint.HughesPJ         (text, vcat)
import           Language.Adder.Types
import           Data.Void
import           Data.List.NonEmpty (NonEmpty (..))

--------------------------------------------------------------------------------
parseFile :: FilePath -> IO (Expr ())
--------------------------------------------------------------------------------
parseFile f = void . parse f <$> readFile f

--------------------------------------------------------------------------------
parse :: FilePath -> Text -> Bare
--------------------------------------------------------------------------------
parse = parseWith expr

parseWith  :: Parser a -> FilePath -> Text -> a
parseWith p f s = case runParser (whole p) f s of
    Left peb@(ParseErrorBundle errors posState) -> -- parse errors; we extract the first error from the error bundle
      let
        ((_, pos) :| _, _) = attachSourcePos errorOffset errors posState
      in
        panic (show (dErr peb)) (SS pos pos)
    Right r -> r -- successful parse with no remaining input
  where
    -- Turns the multiline error string from megaparsec into a pretty-printable Doc.
    dErr e = vcat (map text (lines (errorBundlePretty e)))

-- https://mrkkrp.github.io/megaparsec/tutorials/parsing-simple-imperative-language.html

type Parser = Parsec Void String
--------------------------------------------------------------------------------
-- | Top-Level Expression Parser
--------------------------------------------------------------------------------
expr :: Parser Bare
expr =   try primExpr
     <|> try letExpr
     <|> try (parens expr)
     <|> try constExpr
     <|> idExpr

--------------------------------------------------------------------------------
-- | Individual Sub-Expression Parsers
--------------------------------------------------------------------------------
idExpr :: Parser Bare
idExpr = uncurry Id <$> identifier

constExpr :: Parser Bare
constExpr = uncurry Number <$> integer

primExpr :: Parser Bare
primExpr = withSpan' (Prim1 <$> primOp <*> parens expr)

primOp :: Parser Prim1
primOp
  =  try (rWord "add1"   *> pure Add1)
 <|>     (rWord "sub1"   *> pure Sub1)

letExpr :: Parser Bare
letExpr = withSpan' $ do
  _  <- rWord "let"
  bs <- sepBy1 bind comma
  _  <- rWord "in"
  e  <- expr
  return (bindsExpr bs e)

bind :: Parser (BareBind, Bare)
bind = (,) <$> binder <* symbol "=" <*> expr

--------------------------------------------------------------------------------
-- | Tokenisers and Whitespace
--------------------------------------------------------------------------------

-- | Top-level parsers (should consume all input)
whole :: Parser a -> Parser a
whole p = sc *> p <* eof

-- RJ: rename me "space consumer"
sc :: Parser ()
sc = L.space (void spaceChar) lineCmnt blockCmnt
  where lineCmnt  = L.skipLineComment "//"
        blockCmnt = L.skipBlockComment "/*" "*/"

-- | `symbol s` parses just the string s (and trailing whitespace)
symbol :: String -> Parser String
symbol = L.symbol sc

comma :: Parser String
comma = symbol ","

-- | 'parens' parses something between parenthesis.
parens :: Parser a -> Parser a
parens = betweenS "(" ")"

betweenS :: String -> String -> Parser a -> Parser a
betweenS l r = between (symbol l) (symbol r)

-- | `lexeme p` consume whitespace after running p
lexeme :: Parser a -> Parser (a, SourceSpan)
lexeme p = L.lexeme sc (withSpan p)

-- | 'integer' parses an integer.
integer :: Parser (Integer, SourceSpan)
integer = lexeme L.decimal

-- | `rWord`
rWord   :: String -> Parser SourceSpan
rWord w = snd <$> (withSpan (string w) <* notFollowedBy alphaNumChar <* sc)


-- | list of reserved words
keywords :: [Text]
keywords =
  [ "let"     , "in"
  , "add1"    , "sub1"
  ]

withSpan' :: Parser (SourceSpan -> a) -> Parser a
withSpan' p = do
  p1 <- getSourcePos 
  f  <- p
  p2 <- getSourcePos
  return (f (SS p1 p2))

withSpan :: Parser a -> Parser (a, SourceSpan)
withSpan p = do
  p1 <- getSourcePos
  x  <- p
  p2 <- getSourcePos
  return (x, SS p1 p2)

-- | `binder` parses BareBind, used for let-binds and function parameters.
binder :: Parser BareBind
binder = uncurry Bind <$> identifier

-- | `identifier` parses identifiers: lower-case alphabets followed by alphas or digits
identifier :: Parser (String, SourceSpan)
identifier = lexeme (p >>= check)
  where
    p       = (:) <$> letterChar <*> many alphaNumChar
    check x = if x `elem` keywords
                then fail $ "keyword " ++ show x ++ " cannot be an identifier"
                else return x
