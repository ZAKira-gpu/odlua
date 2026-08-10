// cubit.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:odlua/layout/dishes/add_dishes/add_dishes_screen.dart';
import 'package:odlua/layout/dishes/dishes_screen/dishes_screens.dart';
import 'package:odlua/layout/dishes/listings/listings_screen.dart';
import 'package:odlua/layout/profile/profile_screen.dart';
import 'package:odlua/utils/cubit/states.dart';
import 'package:odlua/utils/cubit/user_model.dart';
import '../../layout/home/home_screen.dart';
import '../helpers/cache_helper.dart';


class OdluaCubit extends Cubit<OdluaStates> {

  OdluaCubit() : super(OdluaInitialState());
  static OdluaCubit get(context) => BlocProvider.of(context);


  UserModel? userModel;
  int currentIndex = 0;

  List<BottomNavigationBarItem> bottomItems = [
    const BottomNavigationBarItem(
      icon: Icon(
        Iconsax.home,
        size: 25,
      ),
      label: 'Home',
    ),
    const BottomNavigationBarItem(
      icon: Icon(
        Icons.menu_book_rounded,
        size: 25,
      ),
      label: 'Menu',
    ),
    const BottomNavigationBarItem(
      icon: Icon(
        Iconsax.add,
        size: 25,
      ),
      label: 'Add',
    ),
    const BottomNavigationBarItem(
      icon: Icon(
        Iconsax.menu_board,
        size: 25,
      ),
      label: 'My Listings',
    ),
    const BottomNavigationBarItem(
      icon: Icon(
        Iconsax.user,
        size: 25,
      ),
      label: 'Profile',
    ),
  ];

  List<Widget> screens = [
    const HomeScreen(),
    const DishesScreen(),
    const AddDishesScreen(),
    const ChefListingsScreen(),
    const ProfileScreen(),
  ];

  bool isDark = false;
  void changeAppMode({bool? fromShared}) {
    if (fromShared != null) {
      isDark = fromShared;
      emit(AppChangeModeState());
    } else {
      isDark = !isDark;
      CacheHelper.putBoolean(key: 'isDark', value: isDark).then((value) {
        emit(AppChangeModeState());
      });
    }
  }

  void changeBottomNavBar(int index) {
    currentIndex = index;
    emit(OdluaBottomNavBarState());
  }

}