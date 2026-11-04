# 有状态协议轨迹校验器

`mqtt/monitor` 是十一月新增的纯计算包，观察一对 MQTT 3.1.1 端点的双向历史。
它不依赖 Scantling 客户端或线性脚本，不执行网络 I/O。
编解码复用 `zbhzs1/moonbit-mqtt@0.1.0`，状态关联与规则判断由本项目实现。

一个 id=7 的 PUBACK 可以完全符合编码格式，但不能完成 id=7 的 QoS 2 事务。
两端同时使用 id=7 是允许的，单方在未完成时把它用于另一笔 SUBSCRIBE 则冲突。
这些结论需要历史和阶段，单包解码或线性匹配不能单独提供。

## 状态与规则

按 `(原始发送端, packet identifier)` 索引事务；两端空间独立，多笔可以交错。

| 事务 | 状态迁移 | 完成条件 |
| --- | --- | --- |
| QoS 0 | PUBLISH | 已观察到报文，仅作协议计数 |
| QoS 1 | PUBLISH → PUBACK | 对端同 id 应答 |
| QoS 2 | PUBLISH → PUBREC → PUBREL → PUBCOMP | 对端同 id 最终应答 |
| 订阅 | SUBSCRIBE → SUBACK | 数量及逐项授权均有效 |
| 退订 | UNSUBSCRIBE → UNSUBACK | 服务端同 id 应答 |

完成后可复用 id。重复在途 PUBLISH 必须有 DUP 且内容相同；重复
PUBREC/PUBREL 不增加完成计数。未知 PUBREL 仍建立待 PUBCOMP 义务，
但不增加应用消息。`completed_publications` 不是应用交付计数。
客户端可以在 CONNACK 前发送控制包；服务端首包仍必须是 CONNACK。

Keep Alive 检查服务端 1.5 倍期限，所有客户端控制包都刷新时间，服务端报文不刷新。
零值禁用期限，关闭事件允许发生在期限之后。本工具不捏造规范规定的 PINGRESP 超时；
只允许一笔未完成 PING 是工具的严格观察策略。客户端 1.0 倍发送期限尚未独立诊断。

## API

包名 `Wchwch777/scantling/mqtt/monitor`；[公开接口](../mqtt/monitor/pkg.generated.mbti)、
[可执行文档](../mqtt/monitor/README.mbt.md)。

- `Monitor::new(max_inflight=1024)` 限制每个方向的在途事务数。
- `observe(sender, packet, at_ms)` 接受已解码包。
- `observe_frame(sender, frame, at_ms)` 另查固定头、精确帧长、尾随字节和 1 MiB 上限。
- `close(at_ms)` 记录 TCP 关闭；`advance(at_ms)` 记录连接在此时仍然打开。
- `report()` 返回脱离内部容器的 JSON 可序列化快照。
- `check_trace(source)` 重放文本；语法错误返回 `Err`，观察诊断保存在 `Ok(report)`。

时间为从调用者指定原点起算的非负、单调毫秒数。每个非注释行是一个事件：

```text
# C=客户端发出，S=服务端发出；每行一个已重组的完整帧。
0 C 100d00044d51545404020000000163
1 S 20020000
2 C 3406000161000778
3 S 40020007
```

此例事件 4 报 `TRACE-ACK-STAGE`：QoS 2 收到 PUBACK。
还支持 `3001 TICK` 和 `4000 CLOSE`。HEX 必须连续；忽略空行和整行注释。
不能直接输入 pcap 或 TCP 分片。

```powershell
$env:SCANTLING_TRACE = "examples/check_trace/traces/interleaved.trace"
moon run --target native examples/check_trace
```

CLI 输出 JSON，只有 `complete=true` 成功退出；错误或未完成时非零退出。
参考目录有 `interleaved`、`persistent-resume`、`wrong-ack`、
`keepalive-overdue`、`incomplete` 五类轨迹，预期结果由测试持续检查。

## 报告与解释边界

| 字段 | 含义 |
| --- | --- |
| `valid_prefix` | 前缀未触发已实现规则或观察策略 |
| `complete` | 此外已有连接尝试，无未完成事务、PING、CONNACK，也没有被丢弃的事务 |
| `pending` | 双向未完成事务数 |
| `abandoned` | Clean Session 结束或切换身份时丢弃的未完成事务数 |
| `diagnostics` | 首个错误的一基事件索引、规则编号及原因 |

`valid_prefix=true, complete=false` 是证据不足，不等于协议违规。
首次诊断后计数和迁移冻结，防止连锁误报。`MQTT-*` 关联规范条款；
`TRACE-*` 是历史关联、输入限制或严格观察策略，不能一概当成客户端违规。
报告不证明应用层恰好交付一次，也不是一致性认证。

Clean Session 关闭会清除状态并累计 `abandoned`，不把中断算完成。
已完整观察的持久会话，以同 client ID、Clean Session=false、
Session Present=true 重连时可以继续 PUBREL 等未完成事务。
未知历史和会话丢失分别返回 `TRACE-SESSION-UNKNOWN` / `TRACE-SESSION-LOST`，
不猜测恢复状态；会话丢失本身不是协议违规，丢失后的两端协调未实现。

只跟踪一对端点的当前会话。不检查订阅路由、Retained/Will 实际投递、
应用层重复消费、全局消息顺序。SUBSCRIBE/UNSUBSCRIBE 重传、捕获丢包、
多笔并行 PING、完整 UTF-8 语义、TLS、MQTT 5、pcap 导入、
系统性模糊测试和全套协议覆盖均不在已验证范围。

## 在线观察

`Peer::run_monitored(timeout_ms=5000)` 为旧脚本增加状态观察和总时限。
客户端原始帧及服务端准备发送的包同时参与检查；脚本准备发送错误 ACK 时，
写出前返回无效报告，避免归罪于客户端。解析、I/O、匹配和超时错误仍抛出。
网络资源在正常、异常和超时退出时清理。

```powershell
$env:SCANTLING_MONITOR = "1"
$env:SCANTLING_FAULT_SCRIPT = "examples/mqtt_fault_peer/scripts/qos2-publish.scantling"
$env:SCANTLING_FAULT_PORT = "18865"
moon run --target native examples/mqtt_fault_peer
```

另开终端：

```sh
mosquitto_pub -V mqttv311 -h 127.0.0.1 -p 18865 -t scantling/ci/qos2 -m independent-mosquitto -q 2
```

CLI 监控模式总时限为 15 秒。故意注入协议错误时可继续用原有非监控模式。
在线模式在事件抵达时检查时间，不主动调度定时器代替 Broker 关闭连接。

协议依据：[OASIS MQTT 3.1.1](https://docs.oasis-open.org/mqtt/mqtt/v3.1.1/os/mqtt-v3.1.1-os.html)
§2.3.1、§3.1–3.3、§3.8–3.14、§4.3、§4.4、§4.7。
代码和轨迹数据为本项目实现，没有复制规范正文或第三方测试集。
