import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'contract.dart';
import 'dart:js_interop';

// JS関数の宣言
@JS('connectWallet')
external JSPromise<JSString> connectWallet();

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: .fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Smart contract test'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  final TextEditingController tag1 = TextEditingController();
  final TextEditingController tag2 = TextEditingController();

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      body: Center(
        child: Column(
          children: [
            Text(
              "Smart Contract test"
            ),
            SizedBox(
              width: 200,
              child: Row(
                children: [
                  Text(
                    "Id"
                  ),
                  const SizedBox(width: 30),
                  Flexible(
                    child: TextFormField(
                      controller: tag2,
                      onChanged: (text)=> setState(() {
                        Id =int.parse(tag2.text);
                      }),
                      keyboardType: TextInputType.number,
                      style: TextStyle(
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: 200,
              child: Row(
                children: [
                  Flexible(
                    child: TextFormField(
                      controller: tag1,
                      onChanged: (text)=> setState(() {
                        amount =int.parse(tag1.text);
                      }),
                      keyboardType: TextInputType.number,
                      style: TextStyle(
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 30),
                  Text("JPYC")
                ],
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
                onPressed:(){
                  CreateEscrow(
                    amount : amount,
                    Id : escrowIdString,
                    deadline: DeadlineBigInt,
                  );
                },
                child: Text("Create")
            ),
            const SizedBox(height: 30),
            //チェックイン
            ElevatedButton(
                onPressed: ()async {
                  await SignExecuteEscrow(
                    escrowId: escrowIdString,
                    payeeAddress: payee,
                    totalAmount: amount
                  );
                  },
                child: Text("Sign")
            ),
            const SizedBox(height: 30),
            //30%バック
            ElevatedButton(
                onPressed: ()async {
                  await SignRefundEscrow(
                      escrowId: escrowIdString,
                      payeeAddress: payee,
                      payerAddress: payer,
                      totalAmount: amount
                  );
                },
                child: Text("Refund")
            ),
          ],

        ),
      ),

      floatingActionButton: FloatingActionButton.extended(
          onPressed: ()async{
            JSString adr = await connectWallet().toDart;
            Address_now = adr.toDart;
          },
            label: Text("Connect")
          ),
    );
  }
}
