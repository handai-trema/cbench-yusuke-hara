#課題 (Cbench のボトルネック調査)
##課題内容
Ruby のプロファイラで Cbench のボトルネックを解析しよう。  
以下に挙げた Ruby のプロファイラのどれかを使い、Cbench や Trema のボトルネック部分を発見し遅い理由を解説してください。
### Ruby 向けのプロファイラ

* [profile](https://docs.ruby-lang.org/ja/2.1.0/library/profile.html)
* [stackprof](https://github.com/tmm1/stackprof)
* [ruby-prof](https://github.com/ruby-prof/ruby-prof)

##解答
今回ボトルネックの解析にはruby-profを用いた．  
コマンドは以下のとおりである．  
```
ruby-prof -s self ./bin/trema run ./lib/cbench_modified.rb >dump.txt
```
-s オプションはどの項目について結果をソートするかを指定する．
selfはメソッド全体の呼び出し時間から他のメソッドの実行時間を除いた時間である．  
結果を以下に示す．  
```
%self      total      self      wait     child     calls  name  
  2.94      8.326     3.291     0.000     5.035   358068  *BinData::BasePrimitive#_value  
  2.48      7.723     2.773     0.000     4.950   307020  *BinData::BasePrimitive#snapshot  
  2.45      6.389     2.739     0.000     3.650   190292   Kernel#clone  
  2.35      2.703     2.627     0.000     0.076   590413   Kernel#respond_to?  
  2.31     26.018     2.583     0.000    23.435   184284   BinData::Base#new  
  2.11      3.547     2.357     0.000     1.190   237237   Kernel#define_singleton_method  
  2.01      3.490     2.246     0.000     1.244   190292   Kernel#initialize_clone    
  1.87      2.088     2.088     0.000     0.000   194228   Symbol#to_s  
  1.78      5.968     1.993     0.000     3.975   126468   Kernel#dup  
  1.78      1.985     1.985     0.000     0.000   197136   BasicObject#!  
```
この結果からBinDataクラスのメソッドが多くの時間を消費している事がわかる．BinDataはtremaではパケットの記述や処理に使われている．cbench.rbを以下に示す．

```
# A simple openflow controller for benchmarking.
class Cbench < Trema::Controller
  def start(_args)
    logger.info 'Cbench started.'
  end

  def packet_in(datapath_id, message)
    send_flow_mod_add(
      datapath_id,
      match: ExactMatch.new(message),
      buffer_id: message.buffer_id,
      actions: SendOutPort.new(message.in_port + 1)
    )
  end
end
```
packet_inメソッド内のマッチングルールを指定するmatchオプションにExactMatchがあるが，
これはPacket inとしてコントローラに入ってきたパケットと12個の条件が全く同じマッチングルール
を生成する．12個の条件とはスイッチの物理ポート番号や送信元MACアドレスなどがある．これらは
パケットから情報を参照しているので，BinDataの\_valueメソッドを何回も呼び出す事となる．
この点が遅い原因となっている．
## 発展課題 (Cbench の高速化)
###課題内容
ボトルネックを改善し Cbench を高速化しよう。
###解答
以下のように修正を行った．

```
# A simple openflow controller for benchmarking.
class Cbench < Trema::Controller
  def start(_args)
    logger.info 'Cbench started.'
  end

  def packet_in(datapath_id, message)
    send_flow_mod_add(
      datapath_id,
      match: Match.new(in_port:message.in_port),
      buffer_id: message.buffer_id,
      actions: SendOutPort.new(message.in_port + 1)
    )
  end
end
```
今回flow modメッセージのアクションはPacket In メッセージのin_portに+1したポートへ転送しているので条件として必要なのはポート番号のみでよい．そこでsend\_flow\_mod\_addのオプションのmatchに

```
match: Match.new(in_port:message.in_port),
```
とポート番号のみを条件とすることで，パケットからの値の呼び出し回数が減りボトルネックが解消される．  
以下に修正前と修正後のcbenchの実行結果を表示する．
####修正前
`
RESULT: 1 switches 9 tests min/max/avg/stdev = 4.83/8.21/6.47/1.05 responses/s
`
####修正後
`RESULT: 1 switches 9 tests min/max/avg/stdev = 6.09/10.47/8.24/1.36 responses/s`

一秒あたりの処理パケット数が平均で6.47から8.24に向上しており，ボトルネックの解消ができたと考えられる．

