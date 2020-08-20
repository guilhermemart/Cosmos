from datetime import datetime
import matplotlib.pyplot as plt
#import pandas as pd
import numpy
#from pandas.plotting import register_matplotlib_converters
register_matplotlib_converters()
import MetaTrader5 as mt5

# conecte-se ao MetaTrader 5
if not mt5.initialize():
    print("initialize() failed")
    mt5.shutdown()

# consultamos o estado e os parâmetros de conexão
print(mt5.terminal_info())
# obtemos informações sobre a versão do MetaTrader 5
print(mt5.version())


# obtemos barras
dolbrl_rates = mt5.copy_rates_range("WDO$", mt5.TIMEFRAME_M1, datetime(2020, 6, 30, 9), datetime(2020, 7, 29, 9))



# DATA

print('dolbrl_rates(', len(dolbrl_rates), ')')
for val in dolbrl_rates[:10000:100]: print(val)



# PLOT
# a partir dos dados recebidos criamos o DataFrame
rates_frame = pd.DataFrame(dolbrl_rates)
# plotamos os ticks no gráfico
plt.plot( rates_frame['close'], 'r-', label='close')
# exibimos rótulos
plt.legend(loc='upper left')

# adicionamos cabeçalho
plt.title('DOLBRL rates')

# mostramos o gráfico
plt.show()
mt5.shutdown()

