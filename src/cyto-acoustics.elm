port module Cytoacoustics exposing (..)

import Html exposing (..)
import Html.App as Html
import Html.Attributes exposing (class)
import Html.Events exposing (onClick, onMouseEnter)
import Array exposing (Array)
import Debug exposing (log)
import Time exposing (..)
import Mouse


main =
  Html.program
    { init = init
    , view = view
    , update = update
    , subscriptions = subscriptions
    }


-- MODEL

size = 16

type alias Matrix = Array (Array Bool)
type alias Model = { matrix: Matrix, clicked: Bool, live: Bool }


init : (Model, Cmd a)
init =
  (Model (Array.repeat size (Array.repeat size False)) False False, Cmd.none)


-- UPDATE


type alias Switch = { row : Int, col : Int }


type Msg = SwitchMsg Switch
  | DragMsg Switch
  | MickeyDown
  | MickeyUp
  | Clear
  | NextStep
  | Tick
  | ToggleLive


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Clear -> init
    SwitchMsg sw ->
      updateHelper sw model
    DragMsg sw ->
      if model.clicked then
        updateHelper sw model
      else
        (model, Cmd.none)
    MickeyDown -> ( { model | clicked = True }, Cmd.none)
    MickeyUp -> ( { model | clicked = False }, Cmd.none)
    NextStep -> ( { model | matrix = nextGeneration model.matrix}, Cmd.none)
    Tick -> ( if model.live then { model | matrix = nextGeneration model.matrix} else model, Cmd.none)
    ToggleLive -> ( { model | live = not model.live }, Cmd.none)


updateHelper : Switch -> Model -> (Model, Cmd Msg)
updateHelper sw model =
  ( { model | matrix = mapElement sw.row model.matrix (\row -> mapElement sw.col row not) }, wasOff model sw)


wasOff : Model -> Switch -> Cmd Msg
wasOff { matrix, clicked } { row, col } =
  let
    wasOff = Maybe.andThen (Array.get row matrix) (\row -> Array.get col row)
      |> Maybe.map not
      |> Maybe.withDefault False
  in
    if wasOff then
      newCells [ ( row, col ) ]
    else
      Cmd.none


mapElement: Int -> Array a -> (a -> a) -> Array a
mapElement idx arr updater =
    Array.get idx arr
      |> Maybe.map (\value -> Array.set idx (updater value) arr)
      |> Maybe.withDefault arr


nextGeneration: Matrix -> Matrix
nextGeneration matrix =
    Array.indexedMap (\x row ->
        Array.indexedMap (\y _ ->
          nextCell matrix x y) row) matrix


nextCell: Matrix -> Int -> Int -> Bool
nextCell matrix rowIdx colIdx =
  List.concatMap (\n -> List.map (\m -> ((rowIdx + n + size) % size, (colIdx + m + size) % size)) [-1, 0, 1]) [-1, 0, 1]
    |> List.filter (\p -> (not ((fst p) == rowIdx && (snd p) == colIdx)))  --filter if m and n == 0
    |> List.filter (\p -> getCell matrix (fst p) (snd p))
    |> List.length
    |> (\l -> ((getCell matrix rowIdx colIdx) && l > 1 && l < 4) || l == 3)


getCell: Matrix -> Int -> Int -> Bool
getCell matrix rowIdx colIdx =
     matrix
         |> Array.get rowIdx
         |> Maybe.withDefault (Array.repeat size False)
         |> Array.get colIdx
         |> Maybe.withDefault False

-- SUBSCRIPTIONS


-- incoming values
port reset : (String -> msg) -> Sub msg

port toggleLive : (String -> msg) -> Sub msg

port nextStep : (String -> msg) -> Sub msg

port newCells : List (Int, Int) -> Cmd msg

subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.batch [
     Mouse.downs (always MickeyDown),
     Mouse.ups (always MickeyUp),
     reset (always Clear),
     nextStep (always NextStep),
     every (500*millisecond) (always Tick),
     toggleLive (always ToggleLive)
  ]


-- VIEW


viewCell : Int -> Int -> Bool -> Html Msg
viewCell row col cell =
    let
      msg = Switch row col
    in
    td [class (if cell then "on" else "off"), onClick (SwitchMsg msg), onMouseEnter (DragMsg msg)] []


viewRow : Int -> Array Bool -> Html Msg
viewRow row cells =
     cells
        |> Array.indexedMap (viewCell row)
        |> Array.toList
        |> tr []


view : Model -> Html Msg
view model =
      model.matrix
        |> Array.indexedMap viewRow
        |> Array.toList
        |> table []
