#!/bin/bash -x
#SBATCH --nodes=2
#SBATCH --gres=gpu:4
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=12
#SBATCH --job-name=bakllava-mistral-7b-dev
#SBATCH --account=laionize
#SBATCH --partition=develbooster
#SBATCH --time=2:00:00
#SBATCH --output /p/project/laionize/marianna/bakllava_original/slurm-output/bakllava-runs-dev-%j.out

CONDA_ENV="/p/project/ccstdl/envs/marianna/bakllava"
MINICONDA_PATH="/p/project/ccstdl/shared/generic/miniconda3"


MODEL_VERSION="mistralai/Mistral-7B-v0.1"
EXP_NAME="bakllava-$MODEL_VERSION-pretrain"

BAKLLAVA_PATH="/p/project/laionize/marianna/bakllava_original/BakLLaVA"

DATA_PATH="/p/scratch/ccstdl/marianna/bakllava/webdataset/blip_laion_cc_sbu/{00000..00127}.tar"
IMAGE_FOLDER="/p/scratch/ccstdl/marianna/bakllava/images.zip"
VISION_TOWER="openai/clip-vit-large-patch14"
OUTPUT_DIR="/p/scratch/ccstdl/marianna/bakllava/checkpoints/$EXP_NAME"

# CHKPT="/p/project/laionize/marianna/mammut/temp_epochs/epoch_77.pt"


source ${MINICONDA_PATH}/bin/activate ${CONDA_ENV}

export NCCL_IB_TIMEOUT=50
export UCX_RC_TIMEOUT=4s
export NCCL_IB_RETRY_CNT=10
export NCCL_IB_DISABLE=1
export NCCL_SOCKET_IFNAME=eth0

export CUDA_VISIBLE_DEVICES="0,1,2,3"
export NCCL_ASYNC_ERROR_HANDLING=1
export GPUS_PER_NODE=8
export MASTER_ADDR="$(scontrol show hostnames $SLURM_JOB_NODELIST | head -n 1)"
export MASTER_PORT=9901
export NUM_NODES=2
export NUM_GPUS=4
export HOSTFILE_PATH="/p/project/laionize/marianna/bakllava_original/hostfile1"

########### DO NOT CHANGE ###########
########### USE THIS FOR BOTH ###########
PROMPT_VERSION=plain
########### DO NOT CHANGE ###########

export PYTHONPATH="$PYTHONPATH:${BAKLLAVA_PATH}"



cd ${BAKLLAVA_PATH}



srun --jobid $SLURM_JOBID python -m torch.distributed.run \
 --nproc_per_node $NUM_GPUS --nnodes $NUM_NODES --node_rank $SLURM_PROCID \
 --master_addr $MASTER_ADDR --master_port $MASTER_PORT  --master_addr=$MASTER_ADDR \
    --master_port=$MASTER_PORT llava/train/train_mem.py \
    --deepspeed ./scripts/zero2.json \
    --model_name_or_path $MODEL_VERSION \
    --version plain \
    --dataset_type "files" \
    --image_folder $IMAGE_FOLDER \
    --data_path $DATA_PATH \
    --vision_tower $VISION_TOWER \
    --tune_mm_mlp_adapter True \
    --mm_vision_select_layer -2 \
    --mm_use_im_start_end False \
    --mm_use_im_patch_token False \
    --bf16 True \
    --output_dir $OUTPUT_DIR \
    --num_train_epochs 1 \
    --per_device_train_batch_size 32 \
    --per_device_eval_batch_size 4 \
    --gradient_accumulation_steps 1 \
    --evaluation_strategy "no" \
    --save_strategy "steps" \
    --save_steps 10 \
    --save_total_limit 1 \
    --learning_rate 2e-3 \
    --weight_decay 0. \
    --warmup_ratio 0.03 \
    --lr_scheduler_type "cosine" \
    --logging_steps 1 \
    --tf32 True \
    --model_max_length 4096 \
    --gradient_checkpointing True \
    --dataloader_num_workers 2 \
    --lazy_preprocess True \
    --report_to wandb
