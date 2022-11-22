import 'dart:math';

import 'package:fahrradwerkstatt/task.dart';

class Statistics {
  final List<QueuedTask> tasks;

  Statistics(this.tasks);

  void printStatitics() {
    List<double> waitTimes = tasks.map((e) => e.totalDuration().toDouble()).toList(growable: false);
    print("Wait times");
    //print(waitTimes);
    printFor(waitTimes);
    List<double> ratios = tasks.map((e) => e.ratio()).toList(growable: false);
    print("Verhätnis");
    //print(ratios);
    printFor(ratios);
  }

  void printFor(List<double> numbers) {
    numbers.sort();
    print("${numbers.reduce(min)} - ${numbers.reduce(max)}");
    double average = numbers.reduce((a, b) => a + b) / tasks.length;
    print("$average");
    print("${_quartile(numbers, 0.25)}");
    print("${_quartile(numbers, 0.5)}");
    print("${_quartile(numbers, 0.75)}");
    print("${_durchschnitlicheAbweichung(numbers, average)}");
    print("${average / _quartile(numbers, 0.5)}");
    print("");
  }

  static double _durchschnitlicheAbweichung(List<double> numbers, double average) {
    double abweichung = 0;
    for (var value in numbers) {
      abweichung += (value - average).abs();
    }
    return abweichung / numbers.length;
  }

  double _quartile(List<double> numbers, double quartile) {
    double index = (numbers.length * quartile) - 1;
    int indexInt = index.toInt();
    double number = numbers[indexInt];
    if (index % 1 == 0) {
      return (number + numbers[indexInt + 1]) / 2;
    }
    return number;
  }
}