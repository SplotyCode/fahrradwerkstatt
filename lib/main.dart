import 'dart:collection';
import 'dart:math';

import 'package:fahrradwerkstatt/task.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:table_calendar/table_calendar.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fahrradwerkstatt',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<TaskDisplay>? _tasks;
  late final ValueNotifier<List<TaskDisplay>> _selectedEvents;
  final DateTime _now = currentDate();
  DateTime? _selected;
  int _end = 1;
  TaskChooserMode mode = TaskChooserMode.first;

  static DateTime currentDate() {
    DateTime now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void initState() {
    super.initState();
    _selectedEvents = ValueNotifier([]);
  }

  List<TaskDisplay> _getEventsForDay(DateTime day) {
    var dayTasks = [..._tasks!];
    int dayOffset = day.difference(_now).inDays;
    dayTasks.removeWhere((element) => dayOffset != element.day());
    return dayTasks;
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    _selected = selectedDay;
    _selectedEvents.value = _getEventsForDay(selectedDay);
  }

  @override
  void dispose() {
    _selectedEvents.dispose();
    super.dispose();
  }

  List<Widget> buildContentWidget(BuildContext context) {
    if (_tasks == null) {
      return <Widget>[
        const Text('Keine Daten ausgewählt'),
        const SizedBox(height: 24.0),
        DropdownButton<TaskChooserMode>(
          value: mode,
          items: TaskChooserMode.values.map((TaskChooserMode value) {
            return DropdownMenuItem<TaskChooserMode>(
              value: value,
              child: Text(value.name),
            );
          }).toList(),
          onChanged: (mode) {
            setState(() {
              this.mode = mode!;
            });
          },
        )
      ];
    }
    return <Widget>[
      TableCalendar(
        firstDay: _now,
        focusedDay: _selected!,
        lastDay: _now.add(Duration(days: _end)),
        eventLoader: _getEventsForDay,
        onDaySelected: _onDaySelected,
      ),
      const SizedBox(height: 8.0),
      Expanded(
        child: ValueListenableBuilder<List<TaskDisplay>>(
          valueListenable: _selectedEvents,
          builder: (context, value, _) {
            return ListView.builder(
              itemCount: value.length,
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12.0,
                    vertical: 4.0,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(),
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: ListTile(
                    onTap: () => print('${value[index]}'),
                    title: Text('${value[index]}'),
                  ),
                );
              },
            );
          },
        ),
      )
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Fahrradwerkstatt"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: buildContentWidget(context),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: chooseFile,
        tooltip: 'Choose file',
        child: const Icon(Icons.drive_folder_upload_rounded),
      ),
    );
  }

  void chooseFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      int totalTasks = 0;
      SplayTreeMap<int, List<Task>> tasks = SplayTreeMap();
      Stream.value(List<int>.from(result.files.single.bytes!))
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((String line) {
        final splited = line.split(' ');
        if (splited.length == 2) {
          Task task = Task(Time(int.parse(splited[0])), int.parse(splited[1]));
          totalTasks++;
          tasks.putIfAbsent(task.start.time, () => []).add(task);
        }
      }, onDone: () {
        applyTasks(tasks, totalTasks);
      }, onError: (e) {
        print(e.toString());
      });
    }
  }

  void applyTasks(SplayTreeMap<int, List<Task>> tasks, int totalTasks) {
    TaskSimulation simulation = TaskSimulation(tasks, mode.create(), totalTasks);
    simulation.simulate();
    setState(() {
      _selected = _now;
      _tasks = simulation.finished
          .expand((element) => element.sessions)
          .toList(growable: false);
      _end = _tasks!.map((e) => e.day()).reduce(max);
    });
    printTasks();
  }

  void printTasks() {
    if (!kDebugMode) {
      return;
    }
    int? day;
    for (final task in _tasks!) {
      int taskDay = task.day();
      if (taskDay != day) {
        print("Tag $taskDay");
        day = taskDay;
      }
      print("  $task");
    }
  }
}
