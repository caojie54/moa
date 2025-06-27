export CUDA_VISIBLE_DEVICES="2"

# Count the number of devices
num_devices=$(echo $CUDA_VISIBLE_DEVICES | awk -F',' '{print NF}')

echo "Number of devices: $num_devices"

max_devices=1

if [ "$num_devices" -gt "$max_devices" ]; then
    num_devices=$max_devices
    echo "max of devices: $max_devices"
fi

# train
epochs=2
dataset="commonsense_15k"
max_seq_len=200
min_gen_len=10
max_gen_len=40

lora_layers="0-32"
lora_rank=8
lora_targets="Q,K,V,O,FFN_DOWN"
lora_alpha=8
hydra_moe=False # hydra lora, Asymmetric LoRA
expert_num=8

blr=6e-3
flash_attention2=False
bf16=True
seed=1225
tag=""
batch_size_gpu=4
eff_batch_size=32
path="/home2/caojie"
output_dir="${path}/outputs/LLaMA3-1_moe/${dataset}/b${batch_size_gpu}_gpu${num_devices}_epoch${epochs}_warme1_loralayers${lora_layers}_lorar${lora_rank}_lora${lora_targets}_alpha${lora_alpha}_expertnum${expert_num}_hydra${hydra_moe}_blr${blr}_maxseq${max_seq_len}_flashatt2${flash_attention2}_bf16${bf16}_seed${seed}_${tag}/"

# torchrun --nproc_per_node $num_devices --master_port=3038 main_finetune.py \
#     --llama_path ${path}/pretrain_models/Meta-Llama-3.1-8B-Instruct/ \
#     --data_path ${path}/datasets/${dataset}/train.json \
#     --expert_num $expert_num \
#     --lora_layers $lora_layers \
#     --lora_rank ${lora_rank} \
#     --lora_targets $lora_targets \
#     --lora_alpha $lora_alpha \
#     --hydra_moe $hydra_moe \
#     --seed $seed \
#     --max_seq_len $max_seq_len \
#     --batch_size  $batch_size_gpu \
#     --accum_iter $(($eff_batch_size/$num_devices/$batch_size_gpu)) \
#     --epochs ${epochs} \
#     --warmup_epochs 1 \
#     --blr ${blr} \
#     --flash_attention2 $flash_attention2 \
#     --bf16 $bf16 \
#     --weight_decay 0.02 \
#     --output_dir $output_dir \
#     --num_workers 10

# checkpoint="${output_dir}checkpoint-$((epochs-1)).pth"
# # get lora parameters
# python extract_adapter_from_checkpoint.py --checkpoint $checkpoint

adapter_path="${output_dir}adapter.pth"


# test_dataset_l="boolq piqa social_i_qa hellaswag winogrande ARC-Challenge ARC-Easy openbookqa"
test_dataset_l="boolq"

max_seq_len=600

for test_dataset in $test_dataset_l
do
save_path="${output_dir}${test_dataset}_mingen${min_gen_len}_routerStats.jsonl"
torchrun --nproc_per_node $num_devices --master_port=3638 example_router_stats.py \
    --ckpt_dir ${path}/pretrain_models/Meta-Llama-3.1-8B-Instruct/ \
    --adapter_path $adapter_path \
    --data_path ${path}/datasets/math_commonsense/${test_dataset}/test.json \
    --save_path $save_path \
    --max_seq_len $max_seq_len \
    --max_gen_len $max_gen_len \
    --min_gen_len $min_gen_len \
    --max_batch_size 1 \
    --max_example 50 \
    --temperature 0.1 \
    --top_p 0.75
done

# save_path1="${output_dir}boolq_predict_mingen${min_gen_len}.jsonl"
# python evaluate_commonsense.py --predict_file $save_path1