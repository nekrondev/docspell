module Comp.EquipmentManage exposing
    ( Model
    , Msg(..)
    , emptyModel
    , update
    , view2
    )

import Api
import Api.Model.BasicResult exposing (BasicResult)
import Api.Model.Equipment
import Api.Model.EquipmentList exposing (EquipmentList)
import Comp.Basic as B
import Comp.EquipmentForm
import Comp.EquipmentTable
import Comp.MenuBar as MB
import Comp.YesNoDimmer
import Data.Flags exposing (Flags)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onSubmit)
import Http
import Styles as S
import Util.Http
import Util.Maybe


type alias Model =
    { tableModel : Comp.EquipmentTable.Model
    , formModel : Comp.EquipmentForm.Model
    , viewMode : ViewMode
    , formError : Maybe String
    , loading : Bool
    , deleteConfirm : Comp.YesNoDimmer.Model
    , query : String
    }


type ViewMode
    = Table
    | Form


emptyModel : Model
emptyModel =
    { tableModel = Comp.EquipmentTable.emptyModel
    , formModel = Comp.EquipmentForm.emptyModel
    , viewMode = Table
    , formError = Nothing
    , loading = False
    , deleteConfirm = Comp.YesNoDimmer.emptyModel
    , query = ""
    }


type Msg
    = TableMsg Comp.EquipmentTable.Msg
    | FormMsg Comp.EquipmentForm.Msg
    | LoadEquipments
    | EquipmentResp (Result Http.Error EquipmentList)
    | SetViewMode ViewMode
    | InitNewEquipment
    | Submit
    | SubmitResp (Result Http.Error BasicResult)
    | YesNoMsg Comp.YesNoDimmer.Msg
    | RequestDelete
    | SetQuery String


update : Flags -> Msg -> Model -> ( Model, Cmd Msg )
update flags msg model =
    case msg of
        TableMsg m ->
            let
                ( tm, tc ) =
                    Comp.EquipmentTable.update flags m model.tableModel

                ( m2, c2 ) =
                    ( { model
                        | tableModel = tm
                        , viewMode = Maybe.map (\_ -> Form) tm.selected |> Maybe.withDefault Table
                        , formError =
                            if Util.Maybe.nonEmpty tm.selected then
                                Nothing

                            else
                                model.formError
                      }
                    , Cmd.map TableMsg tc
                    )

                ( m3, c3 ) =
                    case tm.selected of
                        Just equipment ->
                            update flags (FormMsg (Comp.EquipmentForm.SetEquipment equipment)) m2

                        Nothing ->
                            ( m2, Cmd.none )
            in
            ( m3, Cmd.batch [ c2, c3 ] )

        FormMsg m ->
            let
                ( m2, c2 ) =
                    Comp.EquipmentForm.update flags m model.formModel
            in
            ( { model | formModel = m2 }, Cmd.map FormMsg c2 )

        LoadEquipments ->
            ( { model | loading = True }, Api.getEquipments flags "" EquipmentResp )

        EquipmentResp (Ok equipments) ->
            let
                m2 =
                    { model | viewMode = Table, loading = False }
            in
            update flags (TableMsg (Comp.EquipmentTable.SetEquipments equipments.items)) m2

        EquipmentResp (Err _) ->
            ( { model | loading = False }, Cmd.none )

        SetViewMode m ->
            let
                m2 =
                    { model | viewMode = m }
            in
            case m of
                Table ->
                    update flags (TableMsg Comp.EquipmentTable.Deselect) m2

                Form ->
                    ( m2, Cmd.none )

        InitNewEquipment ->
            let
                nm =
                    { model | viewMode = Form, formError = Nothing }

                equipment =
                    Api.Model.Equipment.empty
            in
            update flags (FormMsg (Comp.EquipmentForm.SetEquipment equipment)) nm

        Submit ->
            let
                equipment =
                    Comp.EquipmentForm.getEquipment model.formModel

                valid =
                    Comp.EquipmentForm.isValid model.formModel
            in
            if valid then
                ( { model | loading = True }, Api.postEquipment flags equipment SubmitResp )

            else
                ( { model | formError = Just "Please correct the errors in the form." }, Cmd.none )

        SubmitResp (Ok res) ->
            if res.success then
                let
                    ( m2, c2 ) =
                        update flags (SetViewMode Table) model

                    ( m3, c3 ) =
                        update flags LoadEquipments m2
                in
                ( { m3 | loading = False }, Cmd.batch [ c2, c3 ] )

            else
                ( { model | formError = Just res.message, loading = False }, Cmd.none )

        SubmitResp (Err err) ->
            ( { model | formError = Just (Util.Http.errorToString err), loading = False }, Cmd.none )

        RequestDelete ->
            update flags (YesNoMsg Comp.YesNoDimmer.activate) model

        YesNoMsg m ->
            let
                ( cm, confirmed ) =
                    Comp.YesNoDimmer.update m model.deleteConfirm

                equip =
                    Comp.EquipmentForm.getEquipment model.formModel

                cmd =
                    if confirmed then
                        Api.deleteEquip flags equip.id SubmitResp

                    else
                        Cmd.none
            in
            ( { model | deleteConfirm = cm }, cmd )

        SetQuery str ->
            let
                m =
                    { model | query = str }
            in
            ( m, Api.getEquipments flags str EquipmentResp )



--- View2


view2 : Model -> Html Msg
view2 model =
    if model.viewMode == Table then
        viewTable2 model

    else
        viewForm2 model


viewTable2 : Model -> Html Msg
viewTable2 model =
    div [ class "flex flex-col" ]
        [ MB.view
            { start =
                [ MB.TextInput
                    { tagger = SetQuery
                    , value = model.query
                    , placeholder = "Search…"
                    , icon = Just "fa fa-search"
                    }
                ]
            , end =
                [ MB.PrimaryButton
                    { tagger = InitNewEquipment
                    , title = "Create a new equipment"
                    , icon = Just "fa fa-plus"
                    , label = "New Equipment"
                    }
                ]
            , rootClasses = "mb-4"
            }
        , Html.map TableMsg (Comp.EquipmentTable.view2 model.tableModel)
        , div
            [ classList
                [ ( "ui dimmer", True )
                , ( "active", model.loading )
                ]
            ]
            [ div [ class "ui loader" ] []
            ]
        ]


viewForm2 : Model -> Html Msg
viewForm2 model =
    let
        newEquipment =
            model.formModel.equipment.id == ""

        dimmerSettings2 =
            Comp.YesNoDimmer.defaultSettings2 "Really delete this equipment?"
    in
    Html.form
        [ class "relative flex flex-col"
        , onSubmit Submit
        ]
        [ Html.map YesNoMsg
            (Comp.YesNoDimmer.viewN
                True
                dimmerSettings2
                model.deleteConfirm
            )
        , if newEquipment then
            h1 [ class S.header2 ]
                [ text "Create new equipment"
                ]

          else
            h1 [ class S.header2 ]
                [ text model.formModel.equipment.name
                , div [ class "opacity-50 text-sm" ]
                    [ text "Id: "
                    , text model.formModel.equipment.id
                    ]
                ]
        , MB.view
            { start =
                [ MB.PrimaryButton
                    { tagger = Submit
                    , title = "Submit this form"
                    , icon = Just "fa fa-save"
                    , label = "Submit"
                    }
                , MB.SecondaryButton
                    { tagger = SetViewMode Table
                    , title = "Back to list"
                    , icon = Just "fa fa-arrow-left"
                    , label = "Cancel"
                    }
                ]
            , end =
                if not newEquipment then
                    [ MB.DeleteButton
                        { tagger = RequestDelete
                        , title = "Delete this equipment"
                        , icon = Just "fa fa-trash"
                        , label = "Delete"
                        }
                    ]

                else
                    []
            , rootClasses = "mb-4"
            }
        , div
            [ classList
                [ ( "hidden", Util.Maybe.isEmpty model.formError )
                ]
            , class S.errorMessage
            , class "my-2"
            ]
            [ Maybe.withDefault "" model.formError |> text
            ]
        , Html.map FormMsg (Comp.EquipmentForm.view2 model.formModel)
        , B.loadingDimmer model.loading
        ]
