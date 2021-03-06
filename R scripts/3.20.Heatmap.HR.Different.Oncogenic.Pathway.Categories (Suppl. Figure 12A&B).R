
#################################################################
###
###
### 
#################################################################

# Setup environment
rm(list=ls())

setwd("~/Dropbox (TBI-Lab)/TCGA Analysis pipeline/")                                                                    # Setwd to location were output files have to be saved.
#setwd("~/Dropbox (TBI-Lab)/External Collaborations/TCGA Analysis pipeline/")    

code_path = "~/Dropbox (Personal)/Jessica PhD Project/QCRI-SIDRA-ICR-Jessica/"                                          # Set code path to the location were the R code is located
#code_path = "~/Dropbox (Personal)/R-projects/QCRI-SIDRA-ICR/" 
#code_path = "C:/Users/whendrickx/R/GITHUB/TCGA_Pipeline/"

source(paste0(code_path, "R tools/ipak.function.R"))
source(paste0(code_path,"R tools/heatmap.3.R"))

required.packages = c("survival","reshape","ggplot2","plyr","Rcpp","colorspace","texreg")
required.bioconductor.packages = c("ComplexHeatmap")
#ibiopak("")
ipak(required.packages)
ibiopak(required.bioconductor.packages)

source(paste0(code_path, "R tools/ggkm.R"))

# Set Parameters
Pathways = "ALL"
CancerTYPES = "ALL"
Cancer_skip = "DLBC"                                                                                                        
download.method = "Assembler_Panca_Normalized_filtered"                                                                          # Specify download method (this information to be used when saving the file)
assay.platform = "gene_RNAseq"                                                                                          # Specify to which location TCGA-Assembler_v2.0.3 was downloaded
Gene.set = "Selected.pathways"
Surv_cutoff_years = 10
Source_surv_data = "Cell_paper"
Outcome = "OS"
Pathway_Category = "Low"
Only_significant = "Only_significant" #"Only_significant" or "all"
Cutoff_HR = 1

# Load data
TCGA.cancersets = read.csv(paste0(code_path, "Datalists/TCGA.datasets.csv"),stringsAsFactors = FALSE)                    # TCGA.datasets.csv is created from Table 1. (Cancer Types Abbreviations) 
# Define parameters (based on loaded data)
if (CancerTYPES == "ALL") { 
  CancerTYPES <- TCGA.cancersets$cancerType
  CancerTYPES = c("Pancancer", CancerTYPES)
}
N.sets = length(CancerTYPES)

pancancer_HR = read.csv(paste0("./4_Analysis/", download.method, "/Pan_Cancer/Survival_Analysis/5.3.All_Pathways_High_and_Low.csv"),
                        stringsAsFactors = FALSE)
pancancer_HR = pancancer_HR[which(pancancer_HR$t.test.fdr.pvalue.Enabled.vs.Disabled < 0.1),]
pancancer_HR_dis = pancancer_HR[which(pancancer_HR$score_contribution == "disabling"),]
pancancer_HR_dis = pancancer_HR_dis[order(pancancer_HR_dis$HR_Low, decreasing = FALSE),]
disabling_pathways = pancancer_HR_dis$Oncogenic_Pathway
pancancer_HR_en = pancancer_HR[which(pancancer_HR$score_contribution == "enabling"),]
pancancer_HR_en = pancancer_HR_en[order(pancancer_HR_en$HR_High, decreasing = TRUE),]
enabling_pathways = pancancer_HR_en$Oncogenic_Pathway

pathways_ordered = c(enabling_pathways, disabling_pathways)


df = data.frame(matrix(ncol=N.sets, nrow = length(pathways_ordered)))
colnames(df) = CancerTYPES
rownames(df) = pathways_ordered

i=2
for (i in 1:N.sets){
  Cancer = CancerTYPES[i]
  if(Cancer == "LAML"){next}
  if(Cancer %in% Cancer_skip){next}
  if(Cancer == "Pancancer"){
    df$Pancancer = pancancer_HR[, paste0("HR_", Pathway_Category)][match(rownames(df), pancancer_HR$Oncogenic_Pathway)]
  }else{
    load(paste0("./4_Analysis/", download.method, "/", Cancer, "/Survival/", Cancer, "_All_Pathways_", Pathway_Category, ".Rdata"))
    if(Only_significant == "Only_significant"){
      results = results[which(results$p_value < 0.05),]
    }
    results$HR[which(results$CI_lower == 0 & results$CI_upper == Inf)] = NA
    df[, Cancer] = results$HR[match(rownames(df), results$pathway)]
  }
}

HR_df = df[-which(colnames(df) %in% c("DLBC", "LAML"))]
save(HR_df, file = paste0("./4_Analysis/", download.method, 
                          "/Pan_Cancer/Survival_Analysis/3.20.HR_df_Pathways_", 
                          Pathway_Category, "_", Only_significant, ".Rdata"))


#########################

# For annotation of df
load(paste0("./4_Analysis/",download.method,"/Pan_Cancer/Survival_Analysis/", Source_surv_data, "_Survival_analysis_High_vs_Low_Groups", 
            "HML_classification.Rdata"))
All_survival_analysis_data = All_survival_analysis_data[-which(All_survival_analysis_data$Cancertype %in% c("LAML", "DLBC")),]
ICR_enabled_cancers = as.character(All_survival_analysis_data$Cancertype[which(All_survival_analysis_data$HR > Cutoff_HR & All_survival_analysis_data$p_value < 0.1)])
ICR_disabled_cancers = as.character(All_survival_analysis_data$Cancertype[which(All_survival_analysis_data$HR <= Cutoff_HR & All_survival_analysis_data$p_value < 0.1)])
ICR_neutral_cancers = as.character(All_survival_analysis_data$Cancertype[which(All_survival_analysis_data$p_value >= 0.1)])
All_survival_analysis_data = All_survival_analysis_data[order(All_survival_analysis_data$HR, decreasing = TRUE),]
Enabled = All_survival_analysis_data[which(All_survival_analysis_data$Cancer %in% ICR_enabled_cancers),]
Disabled = All_survival_analysis_data[which(All_survival_analysis_data$Cancer %in% ICR_disabled_cancers),]
Neutral = All_survival_analysis_data[which(All_survival_analysis_data$Cancer %in% ICR_neutral_cancers),]
Cancer_order = c("Pancancer", as.character(Enabled$Cancertype), as.character(Neutral$Cancertype), as.character(Disabled$Cancertype))

data.info = data.frame(matrix(nrow = ncol(HR_df), ncol = 0), row.names = colnames(HR_df), "ICR.Enabled.Neutral.Disabled" = NA)
data.info$ICR.Enabled.Neutral.Disabled[which(rownames(data.info) %in% ICR_enabled_cancers)] = "ICR enabled"
data.info$ICR.Enabled.Neutral.Disabled[which(rownames(data.info) %in% ICR_disabled_cancers)] = "ICR disabled"
data.info$ICR.Enabled.Neutral.Disabled[which(rownames(data.info) %in% ICR_neutral_cancers)] = "ICR neutral"
data.info$ICR.Enabled.Neutral.Disabled[which(rownames(data.info) == "Pancancer")] = "Pancancer"
data.info$ICR.Enabled.Neutral.Disabled = factor(data.info$ICR.Enabled.Neutral.Disabled, levels = c("Pancancer", "ICR enabled", "ICR neutral", "ICR disabled"))
data.info = data.info[order(match(rownames(data.info), Cancer_order)), ,drop = FALSE]

#col_fun = circlize::colorRamp2(c(min(HR_df, na.rm = TRUE), 1, max(HR_df, na.rm = TRUE)), c("blue", "white", "red"))
col_fun = circlize::colorRamp2(c(0, 1, max(HR_df$Pancancer, na.rm = TRUE)), c("lightblue", "white", "lightgreen"))
ha_column = HeatmapAnnotation(df = data.frame(`ICR Enabled/Neutral/Disabled` = data.info$ICR.Enabled.Neutral.Disabled),
                              show_annotation_name = TRUE,
                              show_legend = FALSE,
                              col = list(`ICR.Enabled.Neutral.Disabled` = c("Pancancer" = "white", "ICR enabled" = "orange", 
                                                                            "ICR neutral" = "grey", "ICR disabled" = "purple"))
                              
)

HR_df = HR_df[,order(match(colnames(HR_df), Cancer_order))]

rownames(HR_df) = gsub(".*] ", "",rownames(HR_df))

# Heatmap
dir.create(paste0("./5_Figures/Pancancer_plots/", download.method, "/HR_Heatmap"), showWarnings = FALSE)
png(paste0("./5_Figures/Pancancer_plots/", download.method, "/HR_Heatmap/v2_HR_Heatmap_Onco_Pathways_", Pathway_Category, "_",
           Only_significant, ".suppl.figure_v2.png"), res = 600, width = 20, height = 12, units = "in")
heatmap = Heatmap(HR_df, 
                  name = paste0("HR between ICR High and ICR Low \n in Pathway ", Pathway_Category, " group"), 
                  cluster_rows = FALSE,
                  cluster_columns = FALSE,
                  row_title_gp = gpar(fontsize = 0.1),
                  column_names_gp = gpar(fontsize = 15),
                  row_names_gp = gpar(fontsize = 15),
                  top_annotation = ha_column,
                  na_col = "lightgrey",
                  col = col_fun,
                  cell_fun = function(j, i, x, y, w, h, col) {
                    if(is.na(HR_df[i, j])){grid.text("")}else{
                    grid.text(HR_df[i, j], x, y)  
                    }
                  },
                  row_names_max_width = unit(6, "in"),
                  column_title = paste0("HR between ICR High and ICR Low \n in Pathway ", Pathway_Category, " group")
)
draw(heatmap, heatmap_legend_side = "bottom")


dev.off()

