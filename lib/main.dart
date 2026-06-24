import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'src/app/app.dart';
part 'src/shared/theme.dart';
part 'src/shared/icons.dart';
part 'src/shared/utils.dart';
part 'src/features/budget/models/budget_models.dart';
part 'src/features/account/models/account_models.dart';
part 'src/features/budget/presentation/thrive_home.dart';
part 'src/features/budget/presentation/thrive_screens.dart';
part 'src/features/budget/presentation/thrive_widgets.dart';
part 'src/features/budget/presentation/thrive_sheets.dart';
part 'src/features/account/presentation/account_actions.dart';
part 'src/features/account/presentation/auth_screen.dart';
part 'src/features/account/presentation/account_sheets.dart';
