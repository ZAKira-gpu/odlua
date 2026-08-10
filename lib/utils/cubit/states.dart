// ─────────────────────────────────────────
// State: OdluaStates
// Description: Cubit state classes for the main app state machine.
// Contains: Loading, success, error states for user data
// ─────────────────────────────────────────


import 'package:odlua/utils/cubit/user_model.dart';

abstract class OdluaStates{}

class OdluaInitialState extends OdluaStates{}

class OdluaBottomNavBarState extends OdluaStates{
  final UserModel? userModel;

  OdluaBottomNavBarState({this.userModel});
}

class OdluaCalendarLoadingState extends OdluaStates {}

class OdluaGetCalendarSuccessState extends OdluaStates {}

class OdluaGetCalendarErrorState extends OdluaStates {
  final String error;

  OdluaGetCalendarErrorState(this.error);
}

class OdluaSearchLoadingState extends OdluaStates{}

class OdluaGetSearchSuccessState extends OdluaStates{}

class OdluaGetSearchErrorState extends OdluaStates{
  final String error;

  OdluaGetSearchErrorState(this.error);
}

class OdluaLoadingState extends OdluaStates {}

class OdluaErrorState extends OdluaStates {
  final String errorMessage;
  OdluaErrorState(this.errorMessage);
}

class OdluaCountryEventsLoadedState extends OdluaStates {
  final List<Map<String, dynamic>> countryEvents;
  OdluaCountryEventsLoadedState(this.countryEvents);
}
class AppChangeModeState extends OdluaStates{
  final UserModel? userModel;

  AppChangeModeState({this.userModel});
}

class OdluaProfileImagePickedSuccessState extends OdluaStates{}

class OdluaProfileImagePickedErrorState extends OdluaStates{}

class OdluaCoverImagePickedSuccessState extends OdluaStates{}

class OdluaCoverImagePickedErrorState extends OdluaStates{}

class OdluaGetUserLoadingState extends OdluaStates{}

class OdluaGetUserSuccessState extends OdluaStates {}

class OdluaGetUserErrorState extends OdluaStates {
  final String errorMessage;

  OdluaGetUserErrorState(this.errorMessage);
}