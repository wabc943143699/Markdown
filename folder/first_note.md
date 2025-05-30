## first note in markdown
### 2025.5.29 22:39
由于line_gran改成了1,现在cache的cam.sv改完了放在了zngz26的vivado/gnn_cache里面, 然后aggr的attention cal也根据line_gran改完了, 还有aggr的aggregation core也改完了。aggr的代码在zngz38的gnn_vivado/rtl里面.

aggr的feature_buf里面有sram还没改。
cache里应该也有还没改的代码。
现在还需要画一下SIMD PE的图，现在它叫做ALU，还有改进版的GAT的图。

### 2025.5.30 11:55
需要跑dma_degree在vivado上,先把zngz38里面的代码copy到寝室的台式机上,然后在这个电脑上跑dma_degree
