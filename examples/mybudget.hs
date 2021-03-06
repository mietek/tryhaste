-- A personal budget application example
-- It uses Google Graphics to draw a chart

{-# LANGUAGE  DeriveDataTypeable #-}

import Haste.HPlay.View
import Haste.HPlay.Cell
import Haste
import Haste.Foreign
import Haste.LocalStorage
import Haste.Serialize
import qualified Data.Map as M
import Data.Monoid
import Data.Maybe
import Control.Monad
import Control.Monad.IO.Class
import qualified Data.List as L
import Prelude hiding (div,span,id)
import Data.Typeable
import Haste.JSON (JSON(..))

data EntryType= Travel | Food | Entertain | Other | Income | AllEntries deriving (Read,Show,Eq, Typeable)

data Entry= Entry{day, month, year :: Int,description :: String, amount :: Double, etype :: EntryType} 
            deriving (Read,Show)


instance Serialize Entry where
  toJSON= Str . toJSString . show
  parseJSON (Str jss)=  return . read  $ fromJSStr jss

data MainOps= Edit | Detail | Prev | Delete

class_ = atr "class"
lb text= span !  class_ "label1" $ text

main= do
  addHeader $ nelem "style"   
           `child` ".label1 {float: left;width: 20%;}"
  addHeader googleGraph

  runBody $ do

    wraw $ h1  "Personal Budget"
  
    r <-wbutton Edit "Edit" <|>
        wbutton Detail "View Entries" <|> 
        wbutton Prev "Preview expenses" 
        <++ hr
        
    case r of
        Edit -> edit
        Detail -> viewEntries
        Prev -> preview
    return ()
  

edit=  do
  entries <- getEntries
  let num = length entries :: Int
  wraw $ div ! id "regnumber" $ b num  <> lb " Registers created:"
  
  r <-  wbutton True "new Entry" <|> wbutton False "Remove Last entry"
  case r of
    True -> newEntry 
    False ->  do
        entries <- getEntries
        if null entries then return () else do
            let entries'= tail entries 
            liftIO $ setEntries  entries'
            let num'= num -1
            at "regnumber" Insert  $ wraw $ b (num') <> lb " registers"
        

newEntry= do
  let focus= atr "autofocus" "true"
  desc <- br ++> lb "Enter description: " ++> inputString Nothing ! atr "size" "40" `fire` OnChange <++ br
  amount <- lb "Enter amount: " ++> inputDouble Nothing !focus  `fire` OnKeyUp <++ br
  
  day   <- getDay
  month <- getMonth
  year  <- getYear

  --let size= atr "size"

  
  (day, month,year) <- lb "Enter Date:" ++> getDate (day,month,year)
  
  typer <- getRadio(
               [\n -> lb "Travel "++> setRadio  Travel  n  `fire` OnClick <++ br
               ,\n -> lb "Food "  ++> setRadio  Food  n  `fire` OnClick <++ br
               ,\n -> lb "Entertainment" ++> setRadio  Entertain n `fire` OnClick <++ br
               ,\n -> lb "Other " ++> setRadio  Other n     `fire` OnClick <++ br
               ,\n -> hr ++> lb "Income " ++> setRadio Income n  `fire` OnClick <++ br])
  
  let newEntry= Entry day month year desc amount typer
  
  h1 "Click here to confirm" `pass` OnClick 
  
  entries <- getEntries
  liftIO $ setEntries $ newEntry  : entries
  let num= length entries + 1  
  
  wraw $ lb "Registered! "
  at "regnumber" Insert $ wraw $ b num <> lb " registers"
  
  


size= atr "size"
length_ = atr "maxlength"


setEntries= setItem "budget"

-- read the entries from Local Storage
getEntries :: Widget [Entry]
getEntries= liftIO $  do
      -- Right registers <- getItem "budget"  <|> return (Right [])

    mr <- getItem "budget"
    case mr of
        Left _ -> return []
        Right list -> return list

viewEntries :: Widget ()
viewEntries= do
   wraw $ br <> lb "from:" 
   today@(d,m,y) <- (,,) <$> getDay <*> getMonth <*> getYear
   (dayf,monthf,yearf) <- getDate (d,if m > 1 then m-1 else m, y)
   wraw $ br <> lb "to:"
   (dayt,montht,yeart) <- getDate today
   
   let filter reg=
        let yearr= year reg; monthr = month reg; dayr= day reg
        
        in  yearr > yearf && yearr < yeart ||
            yearr == yearf && monthr > monthf ||
            yearr == yeart && monthr < montht ||
            monthr == monthf && dayr >= dayf ||
            monthr == monthr && dayr <= dayr
 
   detailByFilter filter  

getDate (day, month, year)= 
         (,,)   <$> inputInt (Just day)    ! length_ "2" ! size "2"
                        `validate` (\d -> return (if d> 1 && d <31 
                                                    then Nothing else Just $ b "wrong"))
                <*> inputInt (Just month)  ! length_ "2" ! size "2"
                        `validate` (\m -> return (if m>1 && m < 12 
                                                    then Nothing else Just $ b "wrong"))
                <*> inputInt (Just year)   ! length_ "4" ! size "4"
                <** inputSubmit "Ok" `fire` OnClick
                <++ br

detailByFilter :: (Entry -> Bool) -> Widget ()
detailByFilter fil  = do
    regs' <- getEntries
    let regs = filter fil regs'
        filterByType type_ rs= filter (\r -> etype r == type_) rs

        total :: EntryType -> Double
        total typer = sum $ L.map amount $ filterByType typer regs
        
        travel= total Travel
        food=   total Food
        enter=  total Entertain
        other=  total Other
        income= total Income
        
        fs=     fromStr
        
    typer <-    lb <<< wlink Income <<  fs " Income: " <++ b income 
            <|> lb <<< wlink Travel <<  fs " Travel: " <++ b  travel
            <|> lb <<< wlink Food   <<  fs " Food: " <++ b  food 
            <|> lb <<< wlink Entertain  << fs " Entertain" <++ b  enter 
            <|> lb <<< wlink Other  <<  fs "Other: " <++ b  other 
            <|> return AllEntries
            <++ do br
                   br
                   lb "Balance: " 
                   b (income - travel - food - enter - other)
            <** drawIt (("Type", "Spent")
                       ,("Travel",  travel)
                       ,("Food",   food)
                       ,("Entertainment", enter)
                       ,("Other",   other)
                       ,("Income",   income))
                       
    let filtered = if typer == AllEntries then regs else filterByType typer regs
    detail  filtered

detail  registers= wraw $ do
    h3 "Al registers selected:"

    div $ do
      lb $ b "Date"
      lb $ b "Description"
      lb $ b "Type"
      lb $ b "Amount"
      br

    let formatEntry (Entry day month year desc amount typer)= 
         div $ do
          lb $ show day++"-"++show month++"-"++show year
          lb $ typer
          lb $ desc
          lb $ amount
          br

    mconcat [formatEntry entry | entry <- registers]
    
  
        
-- preview spenses 



preview= do
    initial@(t,f,e,o,i) <- getSData <|> return (50,50,50,1850,2000) 
    
    changed <-  h3 "Preview" 
            ++> h4 "Recalculate the budget according with priorities and present a chart graph"
            ++> lb "Income"   ++> cell Income i  <++ br 
            <|> lb "Travel" ++> cell Travel t <++ br
            <|> lb "Food"   ++> cell Food f <++ br 
            <|> lb "Entertainment" ++>  cell Entertain e <++ br
            <|> lb "Other"   ++> cell Other o <++ br 
            <|> return AllEntries

    (t,f,e,o,i) <- if changed== AllEntries then return initial else do            
                        t <- get $ boxCell "Travel";    f <- get $ boxCell "Food"
                        e <- get $ boxCell "Entertain"; o <- get $ boxCell "Other"
                        i <- get $ boxCell "Income" :: Widget Double
                        return (t,f,e,o,i)

    setSData (t,f,e,o,i)

    (i,f,o,t,e) <-case changed of
        Travel    -> let e= i - f - o - t in do boxCell "Entertain" .= e ; return  (i,f,o,t,e) 
        Food      -> let e= i - f - o - t in do boxCell "Entertain" .= e ; return  (i,f,o,t,e) 
        Entertain -> let o= i - f - e - t in do boxCell "Other" .= o ; return  (i,f,o,t,e) 
        Other     -> let e= i - f - o - t in do boxCell "Entertain" .= e ; return  (i,f,o,t,e) 
        Income    -> let e= i - f - o - t in do boxCell "Entertain" .= e ; return  (i,f,o,t,e) 
        AllEntries ->return  (i,f,o,t,e) 

    if( t >= 0 && f >= 0 && e >= 0 && o >= 0 && i >= 0) 
      then
       drawIt(("Type", "Spent")
             ,("Travel",  t)
             ,("Food",   f)
             ,("Entertainment", e)
             ,("Other",   o)
             ,("Income",   i))
      else
        wraw $ b "No graphics since some quantity is negative"
    where
    cell :: EntryType -> Double -> Widget EntryType
    cell t v= do
            mk (boxCell (show t) :: Cell Double) (Just v)  `fire` OnKeyUp 
            return t

-- from 
googleGraph :: Perch
googleGraph= do
    script ! atr "type" "text/javascript" ! src "https://www.google.com/jsapi" $ noHtml
    script ! atr "type" "text/javascript" $ do
     "var options;\
     \function init(){\
      \google.load('visualization', '1', {packages:['corechart'],'callback' : drawChart});\
      \function drawChart() {\
        \options = {\
          \title: 'Preview expenses'\
        \};\
      \}}\
     \function waitGoogle(){\
        \if (typeof google !== 'undefined') {init();}\
        \else{window.setTimeout(function(){waitGoogle();}, 10);}}\
     \waitGoogle();"
     
drawIt dat= do
    wraw $ div ! id "piechart" ! style "width: 900px; height: 500px;" $ do
         i "Please connect to Internet to download the "
         a ! href "https://google-developers.appspot.com/chart/interactive/docs/gallery/piechart"
           $ "Pie Chart graphics" 
         i "from Google"
           
    wraw $ liftIO $ drawIt' dat
    where
    drawIt'= ffi $ toJSString 
                "(function (data){\
                 \var chart = new google.visualization.PieChart(document.getElementById('piechart'));\
                 \return chart.draw(google.visualization.arrayToDataTable(data), options);})"

getDay :: Widget Int
getDay= liftIO $ ffi $ toJSString "(function(){return new Date().getDate()})"

getMonth :: Widget Int
getMonth= liftIO $ ffi $ toJSString "(function(){return new Date().getMonth()+1})"

getYear :: Widget Int
getYear= liftIO $ ffi $ toJSString "(function(){return new Date().getFullYear()})"

