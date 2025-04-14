#!/bin/bash

flutter clean

flutter pub get

flutter run -d chrome --web-port=28080 