import 'dart:collection';
import 'dart:math';

import 'package:collection/collection.dart';

const int fullDay = 24 * 60;

class Task {
  final Time start;
  final int duration;

  Task(this.start, this.duration);
}

class Time {
  final int time;

  Time(this.time);

  int day() {
    return time ~/ fullDay;
  }

  String format() {
    return formatOffset(time % fullDay);
  }

  static String formatOffset(int dayOffset) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    int hours = dayOffset ~/ 60;
    return "${twoDigits(hours)}:${twoDigits(dayOffset % 60)}";
  }
}

class TaskDisplay {
  final QueuedTask task;
  final Time start;
  final Time end;

  TaskDisplay(this.task, this.start, this.end);

  int day() {
    return start.day();
  }

  @override
  String toString() {
    String duration = Time.formatOffset(end.time - start.time);
    String totalDuration = Time.formatOffset(task.duration());
    return "${task.name} Um ${start.format()} bis ${end.format()} für $duration von $totalDuration bekommen an Tag ${task.task.start.day()} um ${task.task.start.format()}";
  }
}

class QueuedTask {
  static int id = 0;

  final List<TaskDisplay> sessions = [];
  final String name = "Aufgabe #${++id}";
  final Task task;
  final int at;

  QueuedTask(this.task, this.at);

  int duration() {
    return task.duration;
  }

  int totalDuration() {
    return duration() + _waitTime();
  }

  int _waitTime() {
    return at - task.start.time;
  }

  double ratio() {
    return duration() / totalDuration();
  }
}

abstract class TaskChooser {
  void makeAvailable(WorkingClock workingClock, Task task);

  Task choose(WorkingClock workingClock);
}

enum TaskChooserMode {
  first, shortest, arron;

  TaskChooser create() {
    switch (this) {
      case TaskChooserMode.first:
        return FirstTaskChooser();
      case TaskChooserMode.shortest:
        return ShortestTaskChooser();
      case TaskChooserMode.arron:
        return ArronTaskChooser();
    }
  }
}

class FirstTaskChooser extends TaskChooser {
  Queue<Task> available = Queue<Task>();

  @override
  Task choose(WorkingClock workingClock) {
    return available.removeFirst();
  }

  @override
  makeAvailable(WorkingClock workingClock, Task task) {
    available.addLast(task);
  }
}

class ShortestTaskChooser extends TaskChooser {
  PriorityQueue<Task> queue = PriorityQueue<Task>((a, b) => a.duration - b.duration);

  @override
  Task choose(WorkingClock workingClock) {
    return queue.removeFirst();
  }

  @override
  void makeAvailable(WorkingClock workingClock, Task task) {
    queue.add(task);
  }
}

class ArronTask {
  static const double multiplierPerMinute = 1 / 3000;

  final Task task;
  final int workStart;

  ArronTask(this.task, this.workStart);

  double score(WorkingClock clock, int totalQueueTime) {
    double multiplier = 5 + totalQueueTime * multiplierPerMinute;
    return task.duration * multiplier - (clock.workedTime - workStart);
  }
}

class ArronTaskChooser extends TaskChooser {
  List<ArronTask> arron = [];
  int totalQueueTime = 0;

  @override
  Task choose(WorkingClock workingClock) {
    int? bestIndex;
    double? bestScore;
    for (int i = 0; i < arron.length; i++) {
      ArronTask task = arron[i];
      double score = task.score(workingClock, totalQueueTime);
      if (bestScore == null || score < bestScore) {
        bestIndex = i;
        bestScore = score;
      }
    }
    Task task = arron.removeAt(bestIndex!).task;
    totalQueueTime -= task.duration;
    return task;
  }

  @override
  void makeAvailable(WorkingClock workingClock, Task task) {
    totalQueueTime += task.duration;
    arron.add(ArronTask(task, workingClock.workedTime));
  }
}

class WorkingClock {
  static const int workStart = 9 * 60;
  static const int workEnd = 17 * 60;
  static const int workingTime = workEnd - workStart;
  static const int freeTime = fullDay - workingTime;

  int time = 0;
  int workedTime = 0;
  int dayTimeLeft = 0;

  //TODO optimise
  void work(QueuedTask task) {
    int duration = task.duration();
    workedTime += duration;
    while (true) {
      int work = min(dayTimeLeft, duration);
      task.sessions.add(TaskDisplay(task, Time(time), Time(time + work)));
      time += work;
      duration -= work;
      dayTimeLeft -= work;
      if (duration == 0) {
        return;
      }
      time += freeTime;
      dayTimeLeft = workingTime;
    }
  }

  void skipTo(int time) {
    int localTime = time % fullDay;
    if (localTime >= workEnd) {
      time += (fullDay - localTime) + workStart;
      dayTimeLeft = workingTime;
    } else if (localTime < workStart) {
      time += (localTime - workStart);
      dayTimeLeft = workingTime;
    } else {
      dayTimeLeft = workingTime - (localTime - workStart);
    }
    this.time = time;
  }
}
class TaskSimulation {
  final SplayTreeMap<int, List<Task>> allTasks;
  final TaskChooser taskChooser;
  final List<QueuedTask> finished = [];
  final int totalTasks;

  TaskSimulation(this.allTasks, this.taskChooser, this.totalTasks);

  void simulate() {
    WorkingClock clock = WorkingClock();
    int lastTask = -1;
    int available = 0;
    while (finished.length != totalTasks) {
      int? after;
      while ((after = allTasks.firstKeyAfter(lastTask)) != null && after! <= clock.time) {
        for (var element in allTasks[after]!) {
          taskChooser.makeAvailable(clock, element);
          available += 1;
        }
        lastTask = after;
      }
      if (available == 0) {
        clock.skipTo(after!);
        continue;
      }
      QueuedTask task = QueuedTask(taskChooser.choose(clock), clock.time);
      available--;
      clock.work(task);
      finished.add(task);
    }
  }
}
