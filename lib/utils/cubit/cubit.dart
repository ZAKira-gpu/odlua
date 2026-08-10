// ─────────────────────────────────────────
// State: OdluaCubit
// Description: Primary state manager for user data and navigation.
// Contains: getUserData, changeBottomNavBar, screen list
// ─────────────────────────────────────────

// cubit.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:odlua/layout/dishes/add_dishes/add_dishes_screen.dart';
import 'package:odlua/layout/dishes/dishes_screen/dishes_screens.dart';
import 'package:odlua/layout/seller/chef_dashboard/chef_dashboard_screen.dart';
import 'package:odlua/layout/profile/profile_screen.dart';
import 'package:odlua/utils/cubit/states.dart';
import 'package:odlua/utils/cubit/user_model.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';
import '../../layout/home/home_screen.dart';
import '../helpers/cache_helper.dart';

class OdluaCubit extends Cubit<OdluaStates> {
  OdluaCubit() : super(OdluaInitialState()) {
    // Load cached isChef if available
    final cachedIsChef = CacheHelper.getBoolean(key: 'isChef');
    if (cachedIsChef != null) {
      userModel = UserModel(isChef: cachedIsChef);
    }
  }
  static OdluaCubit get(context) => BlocProvider.of(context);

  UserModel? userModel;
  int currentIndex = 0;

  List<BottomNavigationBarItem> getBottomItems() {
    return [
      BottomNavigationBarItem(
        icon: const Icon(
          Iconsax.home,
          size: 25,
        ),
        label: 'Home'.tr(),
      ),
      BottomNavigationBarItem(
        icon: const Icon(
          Icons.menu_book_rounded,
          size: 25,
        ),
        label: 'Menu'.tr(),
      ),
      BottomNavigationBarItem(
        icon: const Icon(
          Iconsax.add,
          size: 25,
        ),
        label: 'Add'.tr(),
      ),
      BottomNavigationBarItem(
        icon: const Icon(
          Iconsax.chart_square,
          size: 25,
        ),
        label: 'Dashboard'.tr(),
      ),
      BottomNavigationBarItem(
        icon: const Icon(
          Iconsax.user,
          size: 25,
        ),
        label: 'Profile'.tr(),
      ),
    ];
  }

  List<Widget> screens = [
    const HomeScreen(),
    const DishesScreen(),
    const AddDishesScreen(),
    const ChefDashboardScreen(),
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

  Future<void> getUserData({bool forceRefresh = false}) async {
    // Skip if already loading (prevent duplicate calls)
    if (state is OdluaGetUserLoadingState) {
      return;
    }

    emit(OdluaGetUserLoadingState());

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final value = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get()
            .timeout(
              const Duration(seconds: 5),
              onTimeout: () =>
                  throw TimeoutException('User data fetch timed out'),
            );

        if (value.exists && value.data() != null) {
          userModel = UserModel.fromJson(value.data()!);

          // Cache isChef after successful load
          await CacheHelper.putBoolean(
              key: 'isChef', value: userModel?.isChef ?? false);

          emit(OdluaGetUserSuccessState());
        } else {
          emit(OdluaGetUserErrorState('User data not found'));
        }
      } catch (error) {
        DebugHelper.logError(error.toString());
        emit(OdluaGetUserErrorState(error.toString()));
      }
    } else {
      emit(OdluaGetUserErrorState('No user logged in'));
    }
  }
}
