import pandas as pd
from pyecharts import options as opts
from pyecharts.charts import Map

file_path = r"D:\MyAnalyzedProjects\美妆产品可视化分析\database\df_customer_geohash_distribution.xlsx"
df = pd.read_excel(file_path, sheet_name='df_customer_geohash_distributio')

# 检查数据
print("数据前5行：")
print(df.head())
print("\n地理哈希样例：")
print(df['user_geohash'].head())

# 提取省份和数值
provinces = df['user_geohash'].tolist()
values = df['NUM'].tolist()

# 创建数据对
data_pairs = list(zip(provinces, values))

print(f"准备绘制 {len(data_pairs)} 个地区的数据")

# 创建地图
map_chart = (
    Map()
    .add("用户数量", data_pairs, "china")
    .set_global_opts(
        title_opts=opts.TitleOpts(title="美妆用户地域分布地图"),
        visualmap_opts=opts.VisualMapOpts(
            max_=max(values) if values else 340,
            min_=min(values) if values else 100
        ),
    )
)

output_path = r"D:\MyAnalyzedProjects\美妆产品可视化分析\province_value_map.html"
map_chart.render(output_path)
print(f"地图已生成，保存路径：{output_path}")