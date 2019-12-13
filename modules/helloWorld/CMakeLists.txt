cmake_minimum_required(VERSION 2.8.9)
project(helloWorld LANGUAGES CXX)
project (helloWorld)

add_executable(helloWorld main.cpp)
install(TARGETS helloWorld DESTINATION ${CMAKE_INSTALL_PREFIX})
