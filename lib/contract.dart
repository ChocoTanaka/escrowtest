// 3. ABI定義 (createEscrow 関数)
import 'dart:convert';
import 'dart:js_interop';
import 'dart:math';
import 'dart:typed_data';
import 'package:convert/convert.dart';
import 'package:web3dart/web3dart.dart';

@JS('sendTransaction')
external JSPromise<JSString> sendTransaction(JSString to, JSString data);

@JS('signExecuteData')
external JSPromise<JSString> signExcecuteData(
    JSString signerAddress,
    JSString domainJson,
    JSString messageJson);

late int amount;

late int Id;
final escrowIdString = '202609060006';


final BigInt DeadlineBigInt = BigInt.from(1788706800); //UNIX TIME

final String jpycAddress = '0xE7C3D8C9a439feDe00D2600032D5dB0Be71C3c29';

final jpycTokenAddress = EthereumAddress.fromHex(jpycAddress); // SepoliaのJPYCテストトークンアドレス

// アドレス設定
final String Address1 = 'Address1'; //base
final String Address2 = 'Address2'; //meta2
final String Address3 = 'Address3';
final contract = '0x654D644d6cC1e1F74C0CE3AD9958487eF6446fdF';

final payer = EthereumAddress.fromHex(Address1);
final payee = EthereumAddress.fromHex(Address2);
final arbiter = EthereumAddress.fromHex(Address3); // ※コントラクトによってはcreateEscrowに含まれるか確認

final contractAddress = EthereumAddress.fromHex(contract);

late final String Address_now;

// 1. ERC-20 の approve 関数用 ABI
const erc20AbiMap = [
  {
    "inputs": [
      {"name": "spender", "type": "address"},
      {"name": "amount", "type": "uint256"}
    ],
    "name": "approve",
    "outputs": [
      {"name": "", "type": "bool"}
    ],
    "stateMutability": "nonpayable",
    "type": "function"
  }
];

String generateApproveCallData(BigInt trueamount) {
  // Sepolia JPYC トークンのコントラクトアドレス

  // DeployedContract の作成
  final jpycContract = DeployedContract(
    ContractAbi.fromJson(jsonEncode(erc20AbiMap), 'ERC20'),
    jpycTokenAddress,
  );

  // ★ ここで approve 関数オブジェクト（approveFunction）を取得！
  final approveFunction = jpycContract.function('approve');

  // Call Data のエンコード
  final approveCallData = approveFunction.encodeCall([
    contractAddress,
    trueamount,
  ]);

  print('Approve CallData: 0x${hex.encode(approveCallData)}');
  return "0x${hex.encode(approveCallData)}";
}

final abiMap_create =
  [
    {
    "inputs": [
      {"name": "escrowId", "type": "bytes32"},
      {"name": "payee", "type": "address"},
      {"name": "relayer", "type": "address"},
      {"name": "token", "type": "address"},
      {"name": "amount", "type": "uint256"},
      {"name": "deadline", "type": "uint256"}
    ],
      "name": 'createEscrow',
      "outputs": <Map<String, dynamic>>[], // 明示的に空配列を指定
      "stateMutability": 'nonpayable',
      "type": 'function'
    }
  ];
  // jsonEncode で完全に文字列化してから渡す
final abiJson_create = jsonEncode(abiMap_create);
final contract_create = DeployedContract(
  ContractAbi.fromJson(abiJson_create, 'EscrowContract'),
  contractAddress,
);

final abiMap_execute = [
  {
    'inputs': [
      {'name': 'escrowId', 'type': 'bytes32'},
      {'name': 'action', 'type': 'uint8'},
      {
        'components': [
          {'name': 'recipient', 'type': 'address'},
          {'name': 'amount', 'type': 'uint256'}
        ],
        'name': 'allocations',
        'type': 'tuple[]'
      },
    ],
    'name': 'signExecute',
    'outputs': <Map<String, dynamic>>[], // 明示的に空配列を指定
    'stateMutability': 'nonpayable',
    'type': 'function'
  }
];
final abiJson_execute = jsonEncode(abiMap_execute);
final contract_execute = DeployedContract(
  ContractAbi.fromJson(abiJson_execute, 'EscrowContract'),
  contractAddress,
);

Future<void> CreateEscrow({
  required  int amount,
  required String Id,
  required BigInt deadline}) async{
// 金額: 100 JPYC (18 decimals)
  final trueamount = BigInt.from(amount) * BigInt.from(10).pow(18);

  // 文字列を 32 バイトの Uint8List (bytes32) にパディング
  final escrowIdBytes = Uint8List(32);
  final parsedBytes = Uint8List.fromList(Id.codeUnits);
  escrowIdBytes.setRange(0, parsedBytes.length, parsedBytes);

  print('Escrow ID String: $escrowIdString');
  print('Escrow ID Bytes32 (Hex): 0x${hex.encode(escrowIdBytes)}');

  String approveCallDataHex = generateApproveCallData(trueamount);

  // 送信先 (to) は JPYC のアドレス！
  final approveTxHash = await sendTransaction(
      jpycAddress.toJS,
      approveCallDataHex.toJS
  ).toDart;

  print('Approve 送信完了! Hash: ${approveTxHash.toDart}');

  // ★重要: オンチェーンで Approve トランザクションが承認（Blockに採り込まれる）されるまで数秒待ちます
  print('Approve の承認待ち...');
  await Future.delayed(Duration(seconds: 15));

  // 4. トランザクションデータのエンコード (MetaMask等に渡すデータ)
  final functionCall = contract_create.function('createEscrow');
  final transactionData = functionCall.encodeCall([
    escrowIdBytes,
    payee,
    arbiter,
    jpycTokenAddress,
    trueamount,
    DeadlineBigInt
  ]);

  print('Encoded Transaction Data: 0x${hex.encode(transactionData)}');

  final String callDataHex = "0x${hex.encode(transactionData)}";

  final txHash = await sendTransaction(
      contract.toJS,
      callDataHex.toJS
  ).toDart;
  print(txHash);
}

Future<void> SignExecuteEscrow({
  required String escrowId,
  required EthereumAddress payeeAddress,
  required int totalAmount, // 100 JPYC (100 * 10^18)
  int actionDoneIndex = 0, // DONEのenumインデックス
})async{
  // 文字列を 32 バイトの Uint8List (bytes32) にパディング
  final escrowIdBytes = Uint8List(32);
  final parsedBytes = Uint8List.fromList(escrowId.codeUnits);
  escrowIdBytes.setRange(0, parsedBytes.length, parsedBytes);

  final trueamount = BigInt.from(totalAmount) * BigInt.from(10).pow(18);

  // 1. allocations (tuple配列)
  final allocations = [
    [payeeAddress, trueamount]
  ];

  print('Escrow ID Bytes32 (Hex): 0x${hex.encode(escrowIdBytes)}');

  final function = contract_execute.function('signExecute');
  final txData = function.encodeCall([
    escrowIdBytes,
    BigInt.from(actionDoneIndex), // action: DONE (enum index)
    allocations,
  ]);

  print('Encoded CallData: 0x${hex.encode(txData)}');

  final String callDataHex = "0x${hex.encode(txData)}";

  final txHash = await sendTransaction(
      contract.toJS,
      callDataHex.toJS
  ).toDart;
  print("Hash : ${txHash}");
}

//30%返金のテスト
Future<void> SignRefundEscrow({
  required String escrowId,
  required EthereumAddress payeeAddress,
  required EthereumAddress payerAddress,
  required int totalAmount, // 100 JPYC (100 * 10^18)
  int actionRefundIndex = 1, // REFUNDのenumインデックス
  int refundPercentage = 30,  // 3割キャンセル (Payerへ 30%)
})async{
  // 文字列を 32 バイトの Uint8List (bytes32) にパディング
  final escrowIdBytes = Uint8List(32);
  final parsedBytes = Uint8List.fromList(escrowId.codeUnits);
  escrowIdBytes.setRange(0, parsedBytes.length, parsedBytes);

  final trueamount = BigInt.from(totalAmount) * BigInt.from(10).pow(18);

  final backamount = (trueamount * BigInt.from(refundPercentage)) ~/ BigInt.from(100);

  final payamount = trueamount - backamount;

  // 1. allocations (tuple配列)
  final allocations = [
    [payeeAddress, backamount],
    [payerAddress, payamount]
  ];

  print('Escrow ID Bytes32 (Hex): 0x${hex.encode(escrowIdBytes)}');

  final function = contract_execute.function('signExecute');
  final txData = function.encodeCall([
    escrowIdBytes,
    BigInt.from(actionRefundIndex), // action: DONE (enum index)
    allocations,
  ]);

  print('Encoded CallData: 0x${hex.encode(txData)}');

  final String callDataHex = "0x${hex.encode(txData)}";

  final txHash = await sendTransaction(
      contract.toJS,
      callDataHex.toJS
  ).toDart;
  print("Hash : ${txHash}");
}

