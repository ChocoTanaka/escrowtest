# escrowtest

Smart contract test

今回、エスクローを行うにあたって、テストネットに以下のスマートコントラクトを書いた。

[リンク](https://sepolia.etherscan.io/address/0x654d644d6cc1e1f74c0ce3ad9958487ef6446fdf)

これは、このスマートコントラクトの実験用のコードである。

## What for


# Web2の導線にweb3の回線を敷く

一般的にステーブルコイン決済はP2Pを意識しがちだが、web2のもっとも重要な業務である「調停」の部分を欠いている。
調停とはその業務が正式に履行されたか、キャンセルするか、キャンセルしたとして何割の返金を行うかといった業務である。
本スマートコントラクトは、支払者、受取者、調停者（ここではプラットフォームを意味する）の2of3での署名で処理を実行する
エスクローのスマートコントラクトである。

このコントラクトを通して、web2プラットフォームのような調停者は存在するが、カストディを行わないエスクローを行うことができ、
日本のような厳しいカストディ規制のある国でもweb2プラットフォーム型web3決済を実行できる可能性を持つ。

## Diagram

```mermaid
sequenceDiagram
    autonumber
    actor P as Payer (旅行者)
    participant C as Escrow Contract (Sepolia)
    actor A as Arbitrator (Web2 OTA)
    actor R as Payee (宿泊施設)

    Note over P,R: Web2の導線に、Web3の回線を敷く

    %% 1. 予約・デポジット
    P->>C: JPYCをデポジット (Payer, Payee, Arbitrator登録)

    %% 2. 処理フロー（正常系・異常系）
    alt 正常系：チェックイン完了 (2-of-3 署名)
        P->>R: 現地チェックイン (相互確認)
        P->>C: Payer + Payee 署名送信
        C->>R: JPYCをPayeeへ直接送金 (仲裁人の介入なし)

    else 異常系A：キャンセル・返金 (2-of-3 署名)
        P->>A: Web2上でキャンセル申請
        A->>C: Payer + Arbitrator 署名送信
        C->>P: JPYCをPayerへ返金

    else 異常系B：ノーショー・不泊 (2-of-3 署名)
        R->>A: ノーショー申告・証明
        A->>C: Payee + Arbitrator 署名送信
        C->>R: JPYCをPayeeへ送金
    end

 ```

## Contract

```
enum Action {
        DONE,   // 正常完了（Payeeへの全額送金）
        REFUND, // 割合指定キャンセル（PayerとPayeeで分割）
        CANCEL  // 完全キャンセル（Payerへの全額返金）
    }
```
チェックインといった正規の取引成立の場合、DONEで支払者、受取者の2of3の署名で実行する。<br>
中途キャンセルの場合、REFUNDでアロケーションを設定し、支払者、調停者の2of3で返金処理を実行する<br>
受取者都合のキャンセルの場合、CANCELで受取者、調停者の2of3署名でキャンセルを実行する。<br>

```
function createEscrow(
        bytes32 escrowId,
        address payee,
        address relayer,
        address token,
        uint256 amount,
        uint256 deadline
    )
```

escrowIdを任意に作成し、payee、relayer(ここではArbitatorとも称する)を指定、<br>
支払うERC20トークンと数量を指定し、のちに説明するclaimAfterDeadlineのための締め切り時間（deadline UNIX時間）を設定する。<br>
この署名をpayerが行うことで、コントラクトに資金が預けられる。<br>


```
function signExecute(
        bytes32 escrowId,
        Action action,
        Allocation[] calldata allocations
    )
```
Actionの対応、並びにAllocationを返金率等は、web2のプラットフォームを通して作成し、2of3の署名を集めることができたらsignExecuteの通り実行とする。


```
function claimAfterDeadline(bytes32 escrowId)
```
締め切りを過ぎたコントラクトは、これで支払者に全額送金とする。