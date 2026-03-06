户名");
    headerRow.createCell(3).setCellValue("金额");
    headerRow.createCell(4).setCellValue("备注");
    
    // 4. 填充数据
    int rowNum = 1;
    for (CommissionPayDetailDO detail : details) {
        Row dataRow = sheet.createRow(rowNum);
        dataRow.createCell(0).setCellValue(rowNum);
        dataRow.createCell(1).setCellValue(detail.getBankAccount());
        dataRow.createCell(2).setCellValue(detail.getAgentName());
        dataRow.createCell(3).setCellValue(detail.getPayAmount().doubleValue());
        dataRow.createCell(4).setCellValue("佣金发放-" + getBatch().getBatchNo());
        rowNum++;
    }
    
    // 5. 保存文件
    String fileName = "bank_batch_" + batchId + "_" + System.currentTimeMillis() + ".xlsx";
    String filePath = "/data/commission/batch/" + fileName;
    FileOutputStream outputStream = new FileOutputStream(filePath);
    workbook.write(outputStream);
    outputStream.close();
    workbook.close();
    
    return filePath;
}
```

**批量文件上传银行网银**:
- 财务人员登录企业网银系统
- 选择"批量转账"功能
- 上传生成的Excel文件
- 银行系统验证账户余额,提交审批
- 审批通过后,银行执行批量转账

**2. 支付宝/微信批量打款**

**支付宝批量打款API**:
```java
public void batchPayToAlipay(Long batchId) {
    // 1. 查询发放明细
    List<CommissionPayDetailDO> details = commissionPayDetailMapper.selectByBatchId(batchId);
    
    // 2. 构建转账请求
    AlipayFundTransUniTransferRequest request = new AlipayFundTransUniTransferRequest();
    JSONArray transferArray = new JSONArray();
    
    for (CommissionPayDetailDO detail : details) {
        if (StringUtils.isEmpty(detail.getAlipayAccount())) {
            log.warn("业务员{}未配置支付宝账号,跳过", detail.getAgentName());
            continue;
        }
        
        JSONObject transferDetail = new JSONObject();
        transferDetail.put("out_biz_no", "PAY_" + detail.getId());  // 商户订单号
        transferDetail.put("trans_amount", detail.getPayAmount());  // 转账金额
        transferDetail.put("product_code", "TRANS_ACCOUNT_NO_PWD");  // 产品码
        transferDetail.put("biz_scene", "DIRECT_TRANSFER");  // 业务场景
        transferDetail.put("payee_info", new JSONObject()
                .fluentPut("identity", detail.getAlipayAccount())  // 收款账号
                .fluentPut("identity_type", "ALIPAY_LOGON_ID")  // 账号类型
                .fluentPut("name", detail.getAgentName())  // 真实姓名
        );
        transferDetail.put("remark", "佣金发放-" + getBatchNo());
        
        transferArray.add(transferDetail);
    }
    
    request.setBizContent(new JSONObject()
            .fluentPut("transfer_list", transferArray)
            .toString());
    
    // 3. 调用支付宝API
    try {
        AlipayFundTransUniTransferResponse response = alipayClient.execute(request);
        if (response.isSuccess()) {
            // 更新发放状态
            for (int i = 0; i < details.size(); i++) {
                CommissionPayDetailDO detail = details.get(i);
                detail.setPayStatus("SUCCESS");
                detail.setPayTime(LocalDateTime.now());
                detail.setPayOrderNo(response.getOrderId());
                commissionPayDetailMapper.updateById(detail);
                
                // 更新佣金记录的发放状态
                updateCommissionPayStatus(detail.getCommissionIds(), "PAID", getBatchNo());
            }
        } else {
            log.error("支付宝批量转账失败,原因:{}", response.getSubMsg());
            throw new ServiceException("支付宝批量转账失败");
        }
    } catch (AlipayApiException e) {
        log.error("调用支付宝API异常", e);
        throw new ServiceException("支付宝批量转账异常");
    }
}
```

**微信企业付款API**:
```java
public void batchPayToWechat(Long batchId) {
    List<CommissionPayDetailDO> details = commissionPayDetailMapper.selectByBatchId(batchId);
    
    for (CommissionPayDetailDO detail : details) {
        if (StringUtils.isEmpty(detail.getWechatOpenid())) {
            log.warn("业务员{}未配置微信OpenID,跳过", detail.getAgentName());
            continue;
        }
        
        // 构建企业付款请求
        WxEntPayRequest request = new WxEntPayRequest();
        request.setAppid(wechatConfig.getAppId());
        request.setMchId(wechatConfig.getMchId());
        request.setPartnerTradeNo("PAY_" + detail.getId());  // 商户订单号
        request.setOpenid(detail.getWechatOpenid());  // 用户OpenID
        request.setCheckName("FORCE_CHECK");  // 强制校验真实姓名
        request.setReUserName(detail.getAgentName());  // 真实姓名
        request.setAmount(detail.getPayAmount().multiply(new BigDecimal("100")).intValue());  // 金额(分)
        request.setDescription("佣金发放-" + getBatchNo());
        
        try {
            // 调用微信企业付款API
            WxEntPayResult result = wxPayService.getEntPayService().entPay(request);
            
            // 更新发放状态
            detail.setPayStatus("SUCCESS");
            detail.setPayTime(LocalDateTime.now());
            detail.setPayOrderNo(result.getPaymentNo());
            commissionPayDetailMapper.updateById(detail);
            
            // 更新佣金记录
            updateCommissionPayStatus(detail.getCommissionIds(), "PAID", getBatchNo());
            
        } catch (WxPayException e) {
            log.error("微信企业付款失败,业务员:{}, 原因:{}", detail.getAgentName(), e.getMessage());
            detail.setPayStatus("FAILED");
            detail.setFailReason(e.getMessage());
            commissionPayDetailMapper.updateById(detail);
        }
    }
}
```

**3. 发放状态实时更新**

**状态流转**:
```
PENDING(待发放) → SUCCESS(发放成功) / FAILED(发放失败)
```

**发放成功处理**:
```java
private void updateCommissionPayStatus(String commissionIds, String status, String batchNo) {
    if (StringUtils.isEmpty(commissionIds)) {
        return;
    }
    
    // 解析佣金ID列表
    List<Long> ids = Arrays.stream(commissionIds.split(","))
            .map(Long::parseLong)
            .collect(Collectors.toList());
    
    // 批量更新佣金记录状态
    commissionRecordMapper.update(null,
            new LambdaUpdateWrapper<CommissionRecordDO>()
                    .in(CommissionRecordDO::getId, ids)
                    .set(CommissionRecordDO::getStatus, status)
                    .set(CommissionRecordDO::getPayBatchNo, batchNo)
                    .set(CommissionRecordDO::getPayTime, LocalDateTime.now())
    );
}
```

**发放进度推送**:
```java
// 使用WebSocket推送发放进度
public void pushPayProgress(Long batchId, int current, int total, String message) {
    JSONObject progress = new JSONObject();
    progress.put("batchId", batchId);
    progress.put("current", current);
    progress.put("total", total);
    progress.put("percent", current * 100 / total);
    progress.put("message", message);
    
    webSocketService.sendToUser(getCurrentUserId(), "/topic/pay-progress", progress);
}
```

**4. 失败重试机制**

**失败场景**:
- 银行账号错误或已冻结
- 账户余额不足
- 网络超时
- 系统异常

**重试策略**:
```java
@Async
public void retryFailedPayments(Long batchId) {
    // 查询失败的发放明细
    List<CommissionPayDetailDO> failedDetails = commissionPayDetailMapper.selectList(
            new LambdaQueryWrapper<CommissionPayDetailDO>()
                    .eq(CommissionPayDetailDO::getBatchId, batchId)
                    .eq(CommissionPayDetailDO::getPayStatus, "FAILED")
                    .lt(CommissionPayDetailDO::getRetryCount, 3)  // 最多重试3次
    );
    
    for (CommissionPayDetailDO detail : failedDetails) {
        try {
            // 根据渠道重新发放
            if ("ALIPAY".equals(batch.getPayChannel())) {
                retrySinglePayToAlipay(detail);
            } else if ("WECHAT".equals(batch.getPayChannel())) {
                retrySinglePayToWechat(detail);
            }
            
            // 重试成功,更新状态
            detail.setPayStatus("SUCCESS");
            detail.setPayTime(LocalDateTime.now());
            
        } catch (Exception e) {
            log.error("重试发放失败,明细ID:{}, 重试次数:{}", detail.getId(), detail.getRetryCount() + 1, e);
            detail.setPayStatus("FAILED");
            detail.setFailReason(e.getMessage());
        }
        
        // 更新重试次数
        detail.setRetryCount(detail.getRetryCount() + 1);
        commissionPayDetailMapper.updateById(detail);
    }
}
```

**人工补发**:
- 对于重试3次仍失败的记录,需人工介入
- 财务人员核实失败原因(如账号错误需业务员修改账号)
- 问题解决后,点击"手动补发"按钮,单独发放

#### 3.4.3 发放记录查询业务逻辑

**功能概述**:
提供多维度的发放记录查询,支持业务员自主查询和管理员全局查询。

**核心业务规则**:

**1. 业务员端查询**

**查询权限**:
- 业务员只能查询自己的佣金发放记录
- 不能查询其他业务员的记录

**查询条件**:
- 按时间范围筛选(最近3个月/最近6个月/最近1年/自定义)
- 按发放状态筛选(待发放/已发放/发放失败)
- 按佣金类型筛选(首年佣金/续期佣金/管理津贴)

**查询结果展示**:
```java
public Page<CommissionRecordVO> getMyCommissions(CommissionQueryReqVO reqVO) {
    Long agentId = SecurityFrameworkUtils.getLoginUserId();  // 当前登录的业务员ID
    
    Page<CommissionRecordDO> page = commissionRecordMapper.selectPage(
            reqVO.buildPage(),
            new LambdaQueryWrapper<CommissionRecordDO>()
                    .eq(CommissionRecordDO::getAgentId, agentId)
                    .between(reqVO.getStartTime() != null, 
                            CommissionRecordDO::getCreateTime, 
                            reqVO.getStartTime(), reqVO.getEndTime())
                    .eq(reqVO.getStatus() != null, 
                            CommissionRecordDO::getStatus, reqVO.getStatus())
                    .eq(reqVO.getCommissionType() != null,
                            CommissionRecordDO::getCommissionType, reqVO.getCommissionType())
                    .orderByDesc(CommissionRecordDO::getCreateTime)
    );
    
    return CommissionRecordConvert.INSTANCE.convertPage(page);
}
```

**汇总统计**:
```java
public CommissionStatisticsVO getMyStatistics(String settlePeriod) {
    Long agentId = SecurityFrameworkUtils.getLoginUserId();
    
    // 统计各状态佣金金额
    List<Map<String, Object>> stats = commissionRecordMapper.selectMaps(
            new LambdaQueryWrapper<CommissionRecordDO>()
                    .select("status, SUM(commission_amount) AS total_amount, COUNT(*) AS count")
                    .eq(CommissionRecordDO::getAgentId, agentId)
                    .eq(CommissionRecordDO::getSettlePeriod, settlePeriod)
                    .groupBy(CommissionRecordDO::getStatus)
    );
    
    CommissionStatisticsVO result = new CommissionStatisticsVO();
    for (Map<String, Object> stat : stats) {
        String status = (String) stat.get("status");
        BigDecimal amount = (BigDecimal) stat.get("total_amount");
        Integer count = (Integer) stat.get("count");
        
        if ("PENDING".equals(status)) {
            result.setPendingAmount(amount);
            result.setPendingCount(count);
        } else if ("APPROVED".equals(status)) {
            result.setApprovedAmount(amount);
            result.setApprovedCount(count);
        } else if ("PAID".equals(status)) {
            result.setPaidAmount(amount);
            result.setPaidCount(count);
        }
    }
    
    return result;
}
```

**2. 管理员端查询**

**查询权限**:
- 财务人员可查询所有业务员的佣金记录
- 支持导出Excel

**高级筛选**:
- 按业务员姓名/工号模糊搜索
- 按保险公司筛选
- 按金额范围筛选
- 按发放批次筛选

**批量操作**:
- 批量导出选中记录
- 批量标记为异常
- 批量重新计算

**3. 支付凭证管理**

**凭证上传**:
- 银行转账完成后,上传银行回单PDF
- 支付宝/微信自动获取交易凭证
- 凭证URL存储到pay_voucher字段

**凭证查看**:
```java
public String getPayVoucher(Long commissionId) {
    CommissionRecordDO record = commissionRecordMapper.selectById(commissionId);
    if (record == null || !"PAID".equals(record.getStatus())) {
        throw new ServiceException("该佣金尚未发放或不存在");
    }
    
    return record.getPayVoucher();  // 返回凭证URL
}
```

**凭证归档**:
- 每月末,批量下载当月所有支付凭证
- 打包压缩存档到文件服务器
- 保留3年以上用于审计

### 3.5 对账管理逻辑

#### 3.5.1 保司数据导入业务逻辑

**功能概述**:
从保险公司获取佣金结算单,导入系统进行对账。

**核心业务规则**:

**1. Excel批量导入**

**导入文件格式要求**:
- 支持.xls和.xlsx格式
- 第一行必须是表头
- 必填字段:保单号、保费、佣金金额、出单日期
- 可选字段:佣金费率、结算日期、备注

**标准模板**:
| 保单号 | 保费(元) | 佣金费率(%) | 佣金金额(元) | 出单日期 | 结算日期 | 备注 |
|--------|----------|-------------|--------------|----------|----------|------|
| P2026010001 | 10000.00 | 25.00 | 2500.00 | 2026-01-05 | 2026-02-05 | |
| P2026010002 | 5000.00 | 20.00 | 1000.00 | 2026-01-10 | 2026-02-05 | |

**导入解析逻辑**:
```java
public Long importSettlement(MultipartFile file, String insuranceCompany, String settlePeriod) {
    // 1. 校验文件格式
    if (!file.getOriginalFilename().endsWith(".xlsx") && !file.getOriginalFilename().endsWith(".xls")) {
        throw new ServiceException("仅支持Excel格式文件");
    }
    
    // 2. 创建对账批次
    String batchNo = generateSettlementBatchNo(insuranceCompany, settlePeriod);
    SettlementBatchDO batch = new SettlementBatchDO();
    batch.setBatchNo(batchNo);
    batch.setInsuranceCompany(insuranceCompany);
    batch.setSettlePeriod(settlePeriod);
    batch.setImportFileUrl(uploadFile(file));  // 上传文件到OSS
    batch.setStatus("PROCESSING");
    batch.setStartTime(LocalDateTime.now());
    batch.setOperator(SecurityFrameworkUtils.getLoginUsername());
    settlementBatchMapper.insert(batch);
    
    // 3. 异步解析Excel
    CompletableFuture.runAsync(() -> {
        try {
            parseExcelAndImport(file, batch);
        } catch (Exception e) {
            log.error("导入结算单失败,批次号:{}", batchNo, e);
            batch.setStatus("FAILED");
            batch.setRemark("导入失败:" + e.getMessage());
            settlementBatchMapper.updateById(batch);
        }
    });
    
    return batch.getId();
}

private void parseExcelAndImport(MultipartFile file, SettlementBatchDO batch) throws IOException {
    // 1. 读取Excel
    InputStream inputStream = file.getInputStream();
    Workbook workbook = WorkbookFactory.create(inputStream);
    Sheet sheet = workbook.getSheetAt(0);
    
    int totalCount = 0;
    int successCount = 0;
    List<InsuranceSettlementDO> settlements = new ArrayList<>();
    
    // 2. 遍历行(跳过表头)
    for (int i = 1; i <= sheet.getLastRowNum(); i++) {
        Row row = sheet.getRow(i);
        if (row == null) continue;
        
        try {
            // 3. 解析每一行
            String policyNo = getCellValue(row.getCell(0));
            BigDecimal premium = new BigDecimal(getCellValue(row.getCell(1)));
            BigDecimal commissionRate = new BigDecimal(getCellValue(row.getCell(2))).divide(new BigDecimal("100"), 4, RoundingMode.HALF_UP);
            BigDecimal commissionAmount = new BigDecimal(getCellValue(row.getCell(3)));
            Date issueDate = row.getCell(4).getDateCellValue();
            Date settlementDate = row.getCell(5).getDateCellValue();
            
            // 4. 创建结算记录
            InsuranceSettlementDO settlement = new InsuranceSettlementDO();
            settlement.setSettlementNo(batch.getBatchNo());
            settlement.setInsuranceCompany(batch.getInsuranceCompany());
            settlement.setSettlePeriod(batch.getSettlePeriod());
            settlement.setPolicyNo(policyNo);
            settlement.setPremium(premium);
            settlement.setCommissionRate(commissionRate);
            settlement.setCommissionAmount(commissionAmount);
            settlement.setIssueDate(issueDate.toInstant().atZone(ZoneId.systemDefault()).toLocalDate());
            settlement.setSettlementDate(settlementDate.toInstant().atZone(ZoneId.systemDefault()).toLocalDate());
            settlement.setMatchStatus("UNMATCHED");
            
            settlements.add(settlement);
            totalCount++;
            
            // 5. 每1000条批量插入一次
            if (settlements.size() >= 1000) {
                insuranceSettlementMapper.insertBatch(settlements);
                successCount += settlements.size();
                settlements.clear();
            }
            
        } catch (Exception e) {
            log.error("解析Excel第{}行失败", i + 1, e);
        }
    }
    
    // 6. 插入剩余数据
    if (!settlements.isEmpty()) {
        insuranceSettlementMapper.insertBatch(settlements);
        successCount += settlements.size();
    }
    
    // 7. 更新批次状态
    batch.setTotalCount(totalCount);
    batch.setStatus("COMPLETED");
    batch.setEndTime(LocalDateTime.now());
    settlementBatchMapper.updateById(batch);
    
    workbook.close();
    inputStream.close();
    
    log.info("导入结算单完成,批次号:{}, 总数:{}, 成功:{}", batch.getBatchNo(), totalCount, successCount);
}
```

**2. API自动同步**

**对接保司API**:
```java
@Scheduled(cron = "0 0 3 6 * ?")  // 每月6号凌晨3点同步
public void syncSettlementFromInsuranceCompany() {
    String lastMonth = calculateLastMonthPeriod();
    
    // 遍历已对接的保险公司
    List<InsuranceCompanyConfigDO> companies = insuranceCompanyConfigMapper.selectList(
            new LambdaQueryWrapper<InsuranceCompanyConfigDO>()
                    .eq(InsuranceCompanyConfigDO::getApiEnabled, true)
    );
    
    for (InsuranceCompanyConfigDO company : companies) {
        try {
            // 调用保司API获取结算数据
            List<SettlementDataDTO> data = callInsuranceCompanyAPI(company, lastMonth);
            
            // 转换并导入
            importSettlementFromAPI(company.getCompanyName(), lastMonth, data);
            
        } catch (Exception e) {
            log.error("同步{}结算数据失败", company.getCompanyName(), e);
        }
    }
}
```

**3. 数据格式校验**

**校验规则**:
- 保单号不能为空
- 保费必须大于0
- 佣金金额不能为负数
- 佣金费率必须在0-100%之间
- 出单日期不能晚于结算日期

**校验失败处理**:
```java
private void validateSettlementData(InsuranceSettlementDO settlement) {
    List<String> errors = new ArrayList<>();
    
    if (StringUtils.isEmpty(settlement.getPolicyNo())) {
        errors.add("保单号不能为空");
    }
    
    if (settlement.getPremium() == null || settlement.getPremium().compareTo(BigDecimal.ZERO) <= 0) {
        errors.add("保费必须大于0");
    }
    
    if (settlement.getCommissionAmount() == null || settlement.getCommissionAmount().compareTo(BigDecimal.ZERO) < 0) {
        errors.add("佣金金额不能为负数");
    }
    
    if (settlement.getCommissionRate() != null && 
        (settlement.getCommissionRate().compareTo(BigDecimal.ZERO) < 0 || 
         settlement.getCommissionRate().compareTo(BigDecimal.ONE) > 0)) {
        errors.add("佣金费率必须在0-100%之间");
    }
    
    if (!errors.isEmpty()) {
        throw new ValidationException("数据校验失败:" + String.join(";", errors));
    }
}
```

#### 3.5.2 自动对账引擎业务逻辑

**功能概述**:
将保司结算数据与本地佣金记录进行自动比对,识别一致和差异。

**核心业务规则**:

**1. 保单号匹配**

**匹配逻辑**:
```java
public void autoMatch(Long batchId) {
    // 1. 查询该批次的所有结算记录
    List<InsuranceSettlementDO> settlements = insuranceSettlementMapper.selectList(
            new LambdaQueryWrapper<InsuranceSettlementDO>()
                    .eq(InsuranceSettlementDO::getSettlementNo, getBatch(batchId).getBatchNo())
                    .eq(InsuranceSettlementDO::getMatchStatus, "UNMATCHED")
    );
    
    int matchedCount = 0;
    int exceptionCount = 0;
    
    // 2. 逐条匹配
    for (InsuranceSettlementDO settlement : settlements) {
        try {
            // 3. 根据保单号查找本地佣金记录
            CommissionRecordDO localCommission = commissionRecordMapper.selectOne(
                    new LambdaQueryWrapper<CommissionRecordDO>()
                            .eq(CommissionRecordDO::getPolicyNo, settlement.getPolicyNo())
                            .eq(CommissionRecordDO::getInsuranceCompany, settlement.getInsuranceCompany())
                            .eq(CommissionRecordDO::getCommissionType, "FYC")  // 首年佣金
                            .orderByDesc(CommissionRecordDO::getCreateTime)
                            .last("LIMIT 1")
            );
            
            if (localCommission == null) {
                // 4. 本地无记录
                settlement.setMatchStatus("EXCEPTION");
                settlement.setDiffType("NOT_FOUND");
                settlement.setDiffRemark("本地未找到该保单的佣金记录");
                exceptionCount++;
            } else {
                // 5. 比对金额和费率
                boolean isMatch = compareCommission(settlement, localCommission);
                
                if (isMatch) {
                    // 完全匹配
                    settlement.setMatchStatus("MATCHED");
                    settlement.setLocalCommissionId(localCommission.getId());
                    matchedCount++;
                } else {
                    // 有差异
                    settlement.setMatchStatus("EXCEPTION");
                    settlement.setLocalCommissionId(localCommission.getId());
                    exceptionCount++;
                }
            }
            
            insuranceSettlementMapper.updateById(settlement);
            
        } catch (Exception e) {
            log.error("对账失败,保单号:{}", settlement.getPolicyNo(), e);
        }
    }
    
    // 6. 更新批次统计
    SettlementBatchDO batch = getBatch(batchId);
    batch.setMatchedCount(matchedCount);
    batch.setExceptionCount(exceptionCount);
    settlementBatchMapper.updateById(batch);
    
    log.info("对账完成,批次:{}, 匹配:{}, 异常:{}", batch.getBatchNo(), matchedCount, exceptionCount);
}
```

**2. 金额比对**

**比对规则**:
```java
private boolean compareCommission(InsuranceSettlementDO settlement, CommissionRecordDO local) {
    // 1. 比对佣金金额(允许±0.01元误差)
    BigDecimal amountDiff = settlement.getCommissionAmount().subtract(local.getCommissionAmount()).abs();
    BigDecimal tolerance = new BigDecimal("0.01");  // 1分钱误差
    
    if (amountDiff.compareTo(tolerance) > 0) {
        settlement.setDiffType("AMOUNT_DIFF");
        settlement.setDiffAmount(settlement.getCommissionAmount().subtract(local.getCommissionAmount()));
        settlement.setDiffRemark(String.format("金额不一致,保司:%.2f,本地:%.2f,差异:%.2f",
                settlement.getCommissionAmount(),
                local.getCommissionAmount(),
                settlement.getDiffAmount()));
        return false;
    }
    
    // 2. 比对佣金费率(允许±0.01%误差)
    if (settlement.getCommissionRate() != null) {
        BigDecimal rateDiff = settlement.getCommissionRate().subtract(local.getCommissionRate()).abs();
        BigDecimal rateTolerance = new BigDecimal("0.0001");  // 0.01%
        
        if (rateDiff.compareTo(rateTolerance) > 0) {
            settlement.setDiffType("RATE_DIFF");
            settlement.setDiffRemark(String.format("费率不一致,保司:%.2f%%,本地:%.2f%%",
                    settlement.getCommissionRate().multiply(new BigDecimal("100")),
                    local.getCommissionRate().multiply(new BigDecimal("100"))));
            return false;
        }
    }
    
    // 3. 比对保费(允许±1元误差)
    BigDecimal premiumDiff = settlement.getPremium().subtract(local.getPremium()).abs();
    if (premiumDiff.compareTo(BigDecimal.ONE) > 0) {
        settlement.setDiffType("PREMIUM_DIFF");
        settlement.setDiffRemark(String.format("保费不一致,保司:%.2f,本地:%.2f",
                settlement.getPremium(),
                local.getPremium()));
        return false;
    }
    
    // 4. 完全匹配
    return true;
}
```

**3. 费率核对**

**费率一致性检查**:
- 计算实际费率 = 佣金金额 / 保费
- 与保司提供的费率比对
- 与本地规则配置的费率比对
- 三者应保持一致

**费率异常标记**:
```java
private void checkRateConsistency(InsuranceSettlementDO settlement, CommissionRecordDO local) {
    // 计算实际费率
    BigDecimal actualRate = settlement.getCommissionAmount()
            .divide(settlement.getPremium(), 4, RoundingMode.HALF_UP);
    
    // 与保司提供费率比对
    if (settlement.getCommissionRate() != null) {
        BigDecimal diff = actualRate.subtract(settlement.getCommissionRate()).abs();
        if (diff.compareTo(new BigDecimal("0.0001")) > 0) {
            log.warn("保司结算单中费率与金额不匹配,保单号:{}, 标注费率:{}, 实际费率:{}",
                    settlement.getPolicyNo(),
                    settlement.getCommissionRate(),
                    actualRate);
        }
    }
    
    // 与本地费率比对
    BigDecimal localActualRate = local.getCommissionAmount()
            .divide(local.getPremium(), 4, RoundingMode.HALF_UP);
    BigDecimal diff = actualRate.subtract(localActualRate).abs();
    if (diff.compareTo(new BigDecimal("0.0001")) > 0) {
        settlement.setDiffType("RATE_DIFF");
        settlement.setDiffRemark(String.format("实际费率不一致,保司:%s, 本地:%s",
                actualRate.multiply(new BigDecimal("100")) + "%",
                localActualRate.multiply(new BigDecimal("100")) + "%"));
    }
}
```

**4. 异常标记**

**异常类型**:
- NOT_FOUND: 本地无对应佣金记录
- AMOUNT_DIFF: 金额不一致
- RATE_DIFF: 费率不一致
- PREMIUM_DIFF: 保费不一致
- DUPLICATE: 重复对账(同一保单对账多次)

**异常优先级**:
- HIGH: 金额差异超过100元
- MEDIUM: 金额差异10-100元
- LOW: 金额差异小于10元

#### 3.5.3 差异处理流程业务逻辑

**功能概述**:
对对账发现的差异进行人工审核和处理,选择合适的调整方案。

**核心业务规则**:

**1. 差异类型分类**

**按差异原因分类**:
- 本地计算错误: 佣金规则配置错误,需调整本地佣金
- 保司数据错误: 保司结算单有误,需联系保司修正
- 数据不同步: 保单信息变更(如退保、保全)未同步
- 规则理解不一致: 双方对佣金计算规则理解不同

**按处理方式分类**:
- 接受保司数据: 认为保司数据正确,调整本地佣金金额
- 坚持本地数据: 认为本地计算正确,联系保司修正
- 双方协商: 差异较大,需双方沟通确认

**2. 差异原因分析**

**分析工具**:
```java
public DiffAnalysisVO analyzeDiff(Long settlementId) {
    InsuranceSettlementDO settlement = insuranceSettlementMapper.selectById(settlementId);
    CommissionRecordDO local = commissionRecordMapper.selectById(settlement.getLocalCommissionId());
    
    DiffAnalysisVO analysis = new DiffAnalysisVO();
    
    // 1. 基础信息对比
    analysis.setSettlementInfo(convertToDTO(settlement));
    analysis.setLocalInfo(convertToDTO(local));
    
    // 2. 差异明细
    analysis.setAmountDiff(settlement.getCommissionAmount().subtract(local.getCommissionAmount()));
    analysis.setRateDiff(settlement.getCommissionRate().subtract(local.getCommissionRate()));
    analysis.setPremiumDiff(settlement.getPremium().subtract(local.getPremium()));
    
    // 3. 可能原因分析
    List<String> possibleReasons = new ArrayList<>();
    
    if (analysis.getPremiumDiff().abs().compareTo(BigDecimal.ZERO) > 0) {
        possibleReasons.add("保费不一致,可能是保单变更(如加减保)未同步");
    }
    
    if (analysis.getRateDiff().abs().compareTo(new BigDecimal("0.01")) > 0) {
        possibleReasons.add("费率不一致,可能是佣金规则配置错误");
    }
    
    if (analysis.getAmountDiff().abs().compareTo(new BigDecimal("100")) > 0) {
        possibleReasons.add("金额差异较大,建议联系保司确认");
    }
    
    analysis.setPossibleReasons(possibleReasons);
    
    // 4. 建议处理方案
    if (analysis.getAmountDiff().abs().compareTo(new BigDecimal("10")) < 0) {
        analysis.setSuggestedAction("金额差异较小,建议接受保司数据");
    } else {
        analysis.setSuggestedAction("金额差异较大,建议人工审核");
    }
    
    return analysis;
}
```

**3. 调整方案选择**

**方案一: 接受保司数据**
```java
@Transactional(rollbackFor = Exception.class)
public void acceptInsuranceData(Long settlementId, String handler, String remark) {
    // 1. 查询结算记录
    InsuranceSettlementDO settlement = insuranceSettlementMapper.selectById(settlementId);
    CommissionRecordDO local = commissionRecordMapper.selectById(settlement.getLocalCommissionId());
    
    // 2. 调整本地佣金金额
    BigDecimal oldAmount = local.getCommissionAmount();
    BigDecimal newAmount = settlement.getCommissionAmount();
    
    local.setCommissionAmount(newAmount);
    local.setCommissionRate(settlement.getCommissionRate());
    local.setRemark("对账调整:原金额" + oldAmount + ",调整后" + newAmount);
    commissionRecordMapper.updateById(local);
    
    // 3. 如果有分润,同步调整
    List<CommissionSplitDO> splits = commissionSplitMapper.selectBySourceId(local.getId());
    for (CommissionSplitDO split : splits) {
        // 重新计算分润金额
        BigDecimal newSplitAmount = newAmount.multiply(split.getSplitRate())
                .setScale(2, RoundingMode.HALF_UP);
        
        // 更新分润记录
        CommissionRecordDO splitCommission = commissionRecordMapper.selectById(split.getTargetCommissionId());
        splitCommission.setCommissionAmount(newSplitAmount);
        commissionRecordMapper.updateById(splitCommission);
        
        // 更新分润关系
        split.setSplitAmount(newSplitAmount);
        commissionSplitMapper.updateById(split);
    }
    
    // 4. 更新结算记录状态
    settlement.setMatchStatus("MATCHED");
    settlement.setHandleStatus("ACCEPTED");
    settlement.setHandler(handler);
    settlement.setHandleTime(LocalDateTime.now());
    settlement.setDiffRemark(remark);
    insuranceSettlementMapper.updateById(settlement);
    
    // 5. 记录调整日志
    CommissionAdjustmentLogDO log = new CommissionAdjustmentLogDO();
    log.setCommissionId(local.getId());
    log.setAdjustType("SETTLEMENT_DIFF");
    log.setOldAmount(oldAmount);
    log.setNewAmount(newAmount);
    log.setDiffAmount(newAmount.subtract(oldAmount));
    log.setReason("对账差异调整,接受保司数据");
    log.setOperator(handler);
    log.setRemark(remark);
    commissionAdjustmentLogMapper.insert(log);
}
```

**方案二: 坚持本地数据**
```java
public void rejectInsuranceData(Long settlementId, String handler, String remark) {
    InsuranceSettlementDO settlement = insuranceSettlementMapper.selectById(settlementId);
    
    // 标记为已处理,但不调整本地数据
    settlement.setHandleStatus("REJECTED");
    settlement.setHandler(handler);
    settlement.setHandleTime(LocalDateTime.now());
    settlement.setDiffRemark("坚持本地数据:" + remark);
    insuranceSettlementMapper.updateById(settlement);
    
    // 生成异议函,发送给保司
    generateDisputeLetter(settlement, remark);
}
```

**方案三: 双方协商**
```java
public void negotiateWithInsurance(Long settlementId, String handler, String remark) {
    InsuranceSettlementDO settlement = insuranceSettlementMapper.selectById(settlementId);
    
    // 标记为协商中
    settlement.setHandleStatus("NEGOTIATING");
    settlement.setHandler(handler);
    settlement.setHandleTime(LocalDateTime.now());
    settlement.setDiffRemark("双方协商中:" + remark);
    insuranceSettlementMapper.updateById(settlement);
    
    // 发送邮件通知保司联系人
    sendEmailToInsuranceContact(settlement, remark);
}
```

**4. 调整审批流程**

**审批规则**:
- 金额差异小于100元: 财务专员可直接处理
- 金额差异100-1000元: 需财务主管审批
- 金额差异超过1000元: 需总经理审批

**审批流程**:
```java
public void submitForApproval(Long settlementId, String solution, String remark) {
    InsuranceSettlementDO settlement = insuranceSettlementMapper.selectById(settlementId);
    BigDecimal diffAmount = settlement.getDiffAmount().abs();
    
    // 创建审批单
    ApprovalDO approval = new ApprovalDO();
    approval.setBusinessType("SETTLEMENT_DIFF");
    approval.setBusinessId(settlementId);
    approval.setSolution(solution);
    approval.setRemark(remark);
    
    // 根据金额确定审批人
    if (diffAmount.compareTo(new BigDecimal("100")) < 0) {
        approval.setApprover("财务专员");
        approval.setStatus("AUTO_APPROVED");  // 自动通过
        handleSettlementDiff(settlementId, solution, remark);
    } else if (diffAmount.compareTo(new BigDecimal("1000")) < 0) {
        approval.setApprover("财务主管");
        approval.setStatus("PENDING");
    } else {
        approval.setApprover("总经理");
        approval.setStatus("PENDING");
    }
    
    approvalMapper.insert(approval);
}
```

### 3.6 数据权限与安全

#### 3.6.1 数据权限控制

**功能概述**:
确保不同角色只能访问其权限范围内的佣金数据。

**核心业务规则**:

**1. 业务员权限**
- 只能查看自己的佣金记录
- 不能查看其他业务员的佣金
- 不能修改任何佣金数据

**实现方式**:
```java
// 在Mapper层添加数据权限过滤
@DataScope(deptAlias = "d", userAlias = "u")
public List<CommissionRecordDO> selectCommissionList(CommissionQueryReqVO reqVO) {
    // 框架自动添加数据权限SQL
    // WHERE agent_id = 当前登录用户ID
}

// 或在Service层手动添加过滤
public Page<CommissionRecordVO> getCommissionPage(CommissionQueryReqVO reqVO) {
    if (!SecurityFrameworkUtils.hasRole("ADMIN")) {
        // 非管理员,只能查看自己的数据
        Long currentUserId = SecurityFrameworkUtils.getLoginUserId();
        reqVO.setAgentId(currentUserId);
    }
    
    return commissionRecordMapper.selectPage(reqVO);
}
```

**2. 主管/经理权限**
- 可查看直属下级的佣金记录
- 可查看团队汇总数据
- 不能查看平级或上级的佣金

**实现方式**:
```java
public List<Long> getSubordinateIds(Long agentId) {
    // 查询直属下级
    List<SysAgent> subordinates = agentMapper.selectList(
            new LambdaQueryWrapper<SysAgent>()
                    .eq(SysAgent::getParentId, agentId)
    );
    
    return subordinates.stream()
            .map(SysAgent::getId)
            .collect(Collectors.toList());
}

public Page<CommissionRecordVO> getTeamCommissions(CommissionQueryReqVO reqVO) {
    Long currentUserId = SecurityFrameworkUtils.getLoginUserId();
    
    // 获取下级ID列表
    List<Long> subordinateIds = getSubordinateIds(currentUserId);
    subordinateIds.add(currentUserId);  // 包含自己
    
    // 查询团队佣金
    Page<CommissionRecordDO> page = commissionRecordMapper.selectPage(
            reqVO.buildPage(),
            new LambdaQueryWrapper<CommissionRecordDO>()
                    .in(CommissionRecordDO::getAgentId, subordinateIds)
    );
    
    return CommissionRecordConvert.INSTANCE.convertPage(page);
}
```

**3. 财务/管理员权限**
- 可查看所有佣金记录
- 可修改佣金数据(需审批)
- 可导出佣金报表

#### 3.6.2 敏感操作审计

**功能概述**:
记录所有敏感操作的完整日志,用于事后审计和问题追溯。

**核心业务规则**:

**1. 审计日志记录**

**记录范围**:
- 佣金规则新增/修改/删除
- 佣金记录修改/删除
- 佣金审核通过/驳回
- 佣金发放
- 对账差异调整

**日志表设计**:
```sql
CREATE TABLE `audit_log` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `business_type` varchar(32) NOT NULL COMMENT '业务类型',
  `business_id` bigint(20) NOT NULL COMMENT '业务ID',
  `operation` varchar(32) NOT NULL COMMENT '操作类型',
  `operator` varchar(64) NOT NULL COMMENT '操作人',
  `operator_ip` varchar(64) DEFAULT NULL COMMENT '操作IP',
  `old_data` json DEFAULT NULL COMMENT '变更前数据',
  `new_data` json DEFAULT NULL COMMENT '变更后数据',
  `remark` varchar(500) DEFAULT NULL COMMENT '备注',
  `operate_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '操作时间',
  PRIMARY KEY (`id`),
  KEY `idx_business` (`business_type`, `business_id`),
  KEY `idx_operator` (`operator`),
  KEY `idx_operate_time` (`operate_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='审计日志表';
```

**记录实现**:
```java
@Around("@annotation(AuditLog)")
public Object doAuditLog(ProceedingJoinPoint joinPoint, AuditLog auditLog) throws Throwable {
    // 1. 获取操作信息
    String businessType = auditLog.businessType();
    String operation = auditLog.operation();
    
    // 2. 获取业务ID(从方法参数中提取)
    Object[] args = joinPoint.getArgs();
    Long businessId = extractBusinessId(args);
    
    // 3. 查询变更前数据
    Object oldData = queryOldData(businessType, businessId);
    
    // 4. 执行业务方法
    Object result = joinPoint.proceed();
    
    // 5. 查询变更后数据
    Object newData = queryNewData(businessType, businessId);
    
    // 6. 记录审计日志
    AuditLogDO log = new AuditLogDO();
    log.setBusinessType(businessType);
    log.setBusinessId(businessId);
    log.setOperation(operation);
    log.setOperator(SecurityFrameworkUtils.getLoginUsername());
    log.setOperatorIp(ServletUtils.getClientIP());
    log.setOldData(JSONObject.toJSONString(oldData));
    log.setNewData(JSONObject.toJSONString(newData));
    auditLogMapper.insert(log);
    
    return result;
}
```

**2. 操作日志查询**

**查询接口**:
```java
public Page<AuditLogVO> getAuditLogs(AuditLogQueryReqVO reqVO) {
    Page<AuditLogDO> page = auditLogMapper.selectPage(
            reqVO.buildPage(),
            new LambdaQueryWrapper<AuditLogDO>()
                    .eq(reqVO.getBusinessType() != null, 
                        AuditLogDO::getBusinessType, reqVO.getBusinessType())
                    .eq(reqVO.getBusinessId() != null,
                        AuditLogDO::getBusinessId, reqVO.getBusinessId())
                    .eq(reqVO.getOperator() != null,
                        AuditLogDO::getOperator, reqVO.getOperator())
                    .between(reqVO.getStartTime() != null,
                            AuditLogDO::getOperateTime,
                            reqVO.getStartTime(), reqVO.getEndTime())
                    .orderByDesc(AuditLogDO::getOperateTime)
    );
    
    return AuditLogConvert.INSTANCE.convertPage(page);
}
```

**前端展示**:
- 显示操作时间、操作人、操作类型
- 点击可查看变更前后对比
- 支持按时间、操作人、业务类型筛选
- 支持导出审计报告

---

## 四、接口设计

### 4.1 基本法配置接口

#### 4.1.1 职级管理接口

**创建职级**
- 路径: POST /admin-api/commission/rank/create
- 权限: commission:rank:create

**更新职级**
- 路径: PUT /admin-api/commission/rank/update
- 权限: commission:rank:update

**删除职级**
- 路径: DELETE /admin-api/commission/rank/delete
- 权限: commission:rank:delete

**查询职级列表**
- 路径: GET /admin-api/commission/rank/page
- 权限: commission:rank:query

**查询职级详情**
- 路径: GET /admin-api/commission/rank/get
- 权限: commission:rank:query

#### 4.1.2 佣金规则接口

**创建规则**
- 路径: POST /admin-api/commission/rule/create
- 权限: commission:rule:create

**更新规则**
- 路径: PUT /admin-api/commission/rule/update
- 权限: commission:rule:update

**停用规则**
- 路径: PUT /admin-api/commission/rule/disable
- 权限: commission:rule:update

**查询规则列表**
- 路径: GET /admin-api/commission/rule/page
- 权限: commission:rule:query

**查询规则详情**
- 路径: GET /admin-api/commission/rule/get
- 权限: commission:rule:query

**测试规则公式**
- 路径: POST /admin-api/commission/rule/test-formula
- 权限: commission:rule:test

### 4.2 佣金计算接口

**单笔计算**
- 路径: POST /admin-api/commission/calculate/single
- 权限: commission:calculate:execute

**批量计算**
- 路径: POST /admin-api/commission/calculate/batch
- 权限: commission:calculate:execute

**重新计算**
- 路径: POST /admin-api/commission/calculate/recalculate
- 权限: commission:calculate:execute

**查询计算结果**
- 路径: GET /admin-api/commission/record/page
- 权限: commission:record:query

### 4.3 佣金审核接口

**单笔审核通过**
- 路径: POST /admin-api/commission/audit/approve
- 权限: commission:audit:approve

**批量审核通过**
- 路径: POST /admin-api/commission/audit/batch-approve
- 权限: commission:audit:approve

**驳回**
- 路径: POST /admin-api/commission/audit/reject
- 权限: commission:audit:reject

**查询待审核列表**
- 路径: GET /admin-api/commission/audit/pending-page
- 权限: commission:audit:query

### 4.4 佣金发放接口

**创建发放批次**
- 路径: POST /admin-api/commission/pay-batch/create
- 权限: commission:pay:create

**审批发放批次**
- 路径: POST /admin-api/commission/pay-batch/approve
- 权限: commission:pay:approve

**执行发放**
- 路径: POST /admin-api/commission/pay-batch/execute
- 权限: commission:pay:execute

**查询发放批次**
- 路径: GET /admin-api/commission/pay-batch/page
- 权限: commission:pay:query

**查询发放明细**
- 路径: GET /admin-api/commission/pay-detail/page
- 权限: commission:pay:query

### 4.5 对账管理接口

**导入结算单**
- 路径: POST /admin-api/commission/settlement/import
- 权限: commission:settlement:import

**执行对账**
- 路径: POST /admin-api/commission/settlement/match
- 权限: commission:settlement:match

**处理差异**
- 路径: POST /admin-api/commission/settlement/handle-diff
- 权限: commission:settlement:handle

**查询对账批次**
- 路径: GET /admin-api/commission/settlement/batch-page
- 权限: commission:settlement:query

**查询结算明细**
- 路径: GET /admin-api/commission/settlement/page
- 权限: commission:settlement:query

---

## 五、部署与配置

### 5.1 环境要求

**服务器配置**:
- CPU: 4核及以上
- 内存: 8GB及以上
- 硬盘: 100GB及以上(SSD优先)

**软件环境**:
- JDK: 1.8+
- MySQL: 8.0+
- Redis: 6.0+
- Nginx: 1.18+

### 5.2 数据库初始化

**执行顺序**:
1. 创建数据库: `CREATE DATABASE commission DEFAULT CHARACTER SET utf8mb4`
2. 执行DDL脚本: `commission_ddl.sql`
3. 执行初始化数据: `commission_init_data.sql`
4. 执行索引脚本: `commission_index.sql`

### 5.3 应用配置

**application-commission.yml**:
```yaml
commission:
  calculate:
    batch-size: 1000
    async-thread-pool-size: 5
  split:
    max-hierarchy-level: 5
  settlement:
    max-import-rows: 10000
    amount-tolerance: 0.01
```

### 5.4 定时任务配置

**月度发放任务**:
- Cron表达式: `0 0 2 5 * ?`
- 说明: 每月5号凌晨2点生成发放批次

**晋升评估任务**:
- Cron表达式: `0 0 1 1 * ?`
- 说明: 每月1号凌晨1点评估晋升

**对账同步任务**:
- Cron表达式: `0 0 3 6 * ?`
- 说明: 每月6号凌晨3点同步保司数据

---

## 六、开发注意事项

### 6.1 金额精度处理

**强制要求**:
1. 所有金额字段使用BigDecimal类型
2. 金额计算显式指定精度和舍入模式
3. 数据库金额字段统一DECIMAL(12,2)

### 6.2 并发控制

**关键场景**:
1. 佣金审核: 使用乐观锁防止重复审核
2. 发放批次执行: 使用Redis分布式锁
3. 规则修改: 使用数据库行锁

### 6.3 异常处理规范

**自定义异常码**: 在ErrorCodeConstants中定义

**统一异常处理**: 使用@ControllerAdvice捕获异常

---

## 七、测试要点

### 7.1 单元测试

**测试覆盖率**: 核心业务逻辑达到80%以上

**重点测试场景**:
- 佣金计算准确性
- 分润逻辑正确性
- 金额精度处理
- 并发控制有效性

### 7.2 集成测试

**端到端测试场景**:
1. 保单承保→佣金计算→审核→发放 完整流程
2. 多级分润计算验证
3. 对账差异处理流程
4. 批量操作性能测试

---

## 八、项目交付清单

### 8.1 代码交付物

- Controller层: 6个Controller类
- Service层: 10个Service接口及实现
- Mapper层: 12个Mapper接口及XML
- DO实体: 12个实体类
- VO对象: 50+个请求/响应VO
- 枚举类: 5个枚举类

### 8.2 数据库脚本

1. commission_ddl.sql - 表结构
2. commission_init_data.sql - 初始化数据
3. commission_index.sql - 索引

### 8.3 配置文件

- application-commission.yml
- 定时任务配置
- 权限配置

### 8.4 文档交付

- 详细需求文档(本文档)
- API接口文档(Swagger)
- 数据库设计文档
- 部署运维文档

---

**文档结束**

本详细需求文档共约3万字,全面覆盖了PC佣金系统的业务逻辑、功能实现、接口设计和开发规范。文档重点突出业务逻辑说明,删除了冗余的示例代码,为开发团队提供清晰的开发指引。
