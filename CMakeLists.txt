# SPDX-License-Identifier: GPL-2.0-or-later
# SPDX-FileCopyrightText: 2026 Flexomatic81

# Installs the plasmoid and its translations for distribution packages (AUR
# and the like): cmake -S . -B build -DCMAKE_INSTALL_PREFIX=/usr
#                cmake --build build && cmake --install build
# The widget itself is plain QML/JavaScript; nothing gets compiled except the
# translations. Users who install from the KDE Store or a .plasmoid file do
# not need this file, see scripts/build-plasmoid.sh.
cmake_minimum_required(VERSION 3.16)

project(netspeeder VERSION 1.0.0)

find_package(ECM 6.0.0 REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

include(KDEInstallDirs)
include(KDECMakeSettings)

find_package(Plasma 6 REQUIRED)
find_package(KF6I18n REQUIRED)

# <prefix>/share/plasma/plasmoids/io.github.flexomatic81.netspeeder
plasma_install_package(package io.github.flexomatic81.netspeeder)

# po/<lang>/plasma_applet_io.github.flexomatic81.netspeeder.po
# -> <prefix>/share/locale/<lang>/LC_MESSAGES/plasma_applet_io.github.flexomatic81.netspeeder.mo
ki18n_install(po)
