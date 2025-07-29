
/// 交易信号类型
enum TradingSignal {
  buy,      // 买入
  sell,     // 卖出/止盈
  hold,     // 持有
  none      // 无操作
}

/// 交易策略结果
class StrategyResult {
  final TradingSignal signal;
  final String reason;
  final double confidence; // 置信度 0.0-1.0

  StrategyResult({
    required this.signal,
    required this.reason,
    this.confidence = 1.0,
  });

  @override
  String toString() {
    return 'StrategyResult(signal: $signal, reason: $reason, confidence: $confidence)';
  }
}

/// 基金交易策略类
class FundTradingStrategy {
  // 回撤阈值 - 当回撤超过此值时考虑买入
  final double drawdownThreshold;
  
  // 止盈阈值 - 当收益超过此值时考虑卖出
  final double takeProfitThreshold;
  
  // 最大持有期(天) - 超过此天数考虑卖出
  final int maxHoldDays;

  FundTradingStrategy({
    this.drawdownThreshold = 0.05,     // 5%回撤时考虑买入
    this.takeProfitThreshold = 0.15,    // 15%收益时考虑止盈
    this.maxHoldDays = 365,             // 最大持有一年
  });

  /// 基于回撤的买入策略
  StrategyResult checkBuySignal({
    required List<double> drawdownList,
    required int currentIndex,
    double? currentReturn,
  }) {
    // 检查索引有效性
    if (currentIndex < 0 || currentIndex >= drawdownList.length) {
      return StrategyResult(signal: TradingSignal.none, reason: '索引无效');
    }

    final currentDrawdown = drawdownList[currentIndex];
    
    // 当前回撤超过阈值，考虑买入
    if (currentDrawdown >= drawdownThreshold) {
      double confidence = (currentDrawdown / (drawdownThreshold * 2)).clamp(0.0, 1.0);
      return StrategyResult(
        signal: TradingSignal.buy,
        reason: '当前回撤${(currentDrawdown * 100).toStringAsFixed(2)}%超过阈值${(drawdownThreshold * 100).toStringAsFixed(2)}%',
        confidence: confidence,
      );
    }

    return StrategyResult(signal: TradingSignal.hold, reason: '回撤未达阈值');
  }

  /// 基于收益的止盈策略
  StrategyResult checkSellSignal({
    required double currentReturn,
    required int holdDays,
  }) {
    // 达到止盈点
    if (currentReturn >= takeProfitThreshold) {
      double confidence = (currentReturn / (takeProfitThreshold * 1.5)).clamp(0.0, 1.0);
      return StrategyResult(
        signal: TradingSignal.sell,
        reason: '当前收益${(currentReturn * 100).toStringAsFixed(2)}%达到止盈点${(takeProfitThreshold * 100).toStringAsFixed(2)}%',
        confidence: confidence,
      );
    }

    // 持有时间过长
    if (holdDays >= maxHoldDays) {
      return StrategyResult(
        signal: TradingSignal.sell,
        reason: '持有时间$holdDays天超过最大持有期$maxHoldDays天',
        confidence: 0.8,
      );
    }

    return StrategyResult(signal: TradingSignal.hold, reason: '未达止盈条件');
  }

  /// 综合交易信号判断
  StrategyResult getTradingSignal({
    required List<double> drawdownList,
    required int currentIndex,
    double? currentReturn,
    int? holdDays = 0,
  }) {
    // 检查买入信号
    final buySignal = checkBuySignal(
      drawdownList: drawdownList,
      currentIndex: currentIndex,
      currentReturn: currentReturn,
    );

    if (buySignal.signal == TradingSignal.buy) {
      return buySignal;
    }

    // 如果有持仓信息，检查卖出信号
    if (currentReturn != null && holdDays != null) {
      final sellSignal = checkSellSignal(
        currentReturn: currentReturn,
        holdDays: holdDays,
      );

      if (sellSignal.signal == TradingSignal.sell) {
        return sellSignal;
      }
    }

    return StrategyResult(signal: TradingSignal.hold, reason: '建议继续持有');
  }
}

/// 移动平均线策略
class MovingAverageStrategy {
  final int shortPeriod;  // 短期均线周期
  final int longPeriod;   // 长期均线周期

  MovingAverageStrategy({
    this.shortPeriod = 5,
    this.longPeriod = 20,
  });

  /// 计算简单移动平均线
  double _calculateSMA(List<double> prices, int period, int index) {
    if (index < period - 1) return 0.0;
    
    double sum = 0.0;
    for (int i = 0; i < period; i++) {
      sum += prices[index - i];
    }
    return sum / period;
  }

  /// 检查均线交易信号
  StrategyResult checkSignal(List<double> prices, int currentIndex) {
    if (currentIndex < longPeriod) {
      return StrategyResult(signal: TradingSignal.none, reason: '数据不足');
    }

    final shortMA = _calculateSMA(prices, shortPeriod, currentIndex);
    final longMA = _calculateSMA(prices, longPeriod, currentIndex);
    final prevShortMA = _calculateSMA(prices, shortPeriod, currentIndex - 1);
    final prevLongMA = _calculateSMA(prices, longPeriod, currentIndex - 1);

    // 金叉：短期均线上穿长期均线
    if (prevShortMA <= prevLongMA && shortMA > longMA) {
      return StrategyResult(
        signal: TradingSignal.buy,
        reason: '出现金叉：$shortPeriod日均线上穿$longPeriod日均线',
        confidence: 0.8,
      );
    }

    // 死叉：短期均线下穿长期均线
    if (prevShortMA >= prevLongMA && shortMA < longMA) {
      return StrategyResult(
        signal: TradingSignal.sell,
        reason: '出现死叉：$shortPeriod日均线下穿$longPeriod日均线',
        confidence: 0.8,
      );
    }

    return StrategyResult(signal: TradingSignal.hold, reason: '均线无明显信号');
  }
}

/// RSI相对强弱指数策略
class RSIStrategy {
  final int period;       // RSI周期
  final double overbought; // 超买阈值
  final double oversold;   // 超卖阈值

  RSIStrategy({
    this.period = 14,
    this.overbought = 70.0,
    this.oversold = 30.0,
  });

  /// 计算RSI指标
  double _calculateRSI(List<double> prices, int index) {
    if (index < period) return 50.0;

    double gains = 0.0;
    double losses = 0.0;

    for (int i = index - period + 1; i <= index; i++) {
      final change = prices[i] - prices[i - 1];
      if (change > 0) {
        gains += change;
      } else {
        losses -= change; // 注意：losses保持正值
      }
    }

    final avgGain = gains / period;
    final avgLoss = losses / period;

    if (avgLoss == 0) return 100.0;
    final rs = avgGain / avgLoss;
    final rsi = 100 - (100 / (1 + rs));
    
    return rsi;
  }

  /// 检查RSI交易信号
  StrategyResult checkSignal(List<double> prices, int currentIndex) {
    if (currentIndex < period) {
      return StrategyResult(signal: TradingSignal.none, reason: '数据不足');
    }

    final rsi = _calculateRSI(prices, currentIndex);
    final prevRSI = _calculateRSI(prices, currentIndex - 1);

    // 超卖区域向上突破，买入信号
    if (prevRSI <= oversold && rsi > oversold) {
      final confidence = 1.0 - ((rsi - oversold) / (50 - oversold));
      return StrategyResult(
        signal: TradingSignal.buy,
        reason: 'RSI从超卖区${rsi.toStringAsFixed(2)}回升',
        confidence: confidence.clamp(0.0, 1.0),
      );
    }

    // 超买区域向下突破，卖出信号
    if (prevRSI >= overbought && rsi < overbought) {
      final confidence = 1.0 - ((overbought - rsi) / (overbought - 50));
      return StrategyResult(
        signal: TradingSignal.sell,
        reason: 'RSI从超买区${rsi.toStringAsFixed(2)}回落',
        confidence: confidence.clamp(0.0, 1.0),
      );
    }

    return StrategyResult(signal: TradingSignal.hold, reason: 'RSI无明显信号');
  }
}