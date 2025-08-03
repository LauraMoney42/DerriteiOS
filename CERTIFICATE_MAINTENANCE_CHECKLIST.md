# Certificate Pinning Maintenance Checklist

This checklist helps you maintain certificate pinning security for the Derrite iOS app.

## 🚨 Emergency Response (Certificate Rotation Detected)

### Immediate Actions (Within 24 hours)
- [ ] **Verify the certificate change** - Confirm it's legitimate Railway.app rotation, not a security incident
- [ ] **Extract new certificate hashes** using CertificateHashExtractor development tool
- [ ] **Update both iOS and Android apps** with new certificate hashes
- [ ] **Test pinning functionality** on development builds before release
- [ ] **Deploy updated apps** to App Store/Play Store with expedited review if needed

### Emergency Fallback
- [ ] **Monitor app connectivity** - Certificate pinning includes fallback mode to prevent total app breakage
- [ ] **Check security logs** - Review OSLog entries for pinning failures
- [ ] **Notify users if needed** - If app functionality is impacted

---

## 📅 Regular Maintenance Schedule

### Monthly Tasks (1st of each month)
- [ ] **Check certificate expiration dates**
  - Railway.app certificates typically rotate every ~90 days
  - Monitor for upcoming rotations 30 days in advance
- [ ] **Review security logs** for any pinning failures or unusual activity
- [ ] **Test development certificate extraction tool** to ensure it's working

### Quarterly Tasks (Every 3 months)
- [ ] **Update certificate hashes** even if no rotation detected (proactive maintenance)
- [ ] **Review pinning configuration** and security policies
- [ ] **Test failover scenarios** in development environment
- [ ] **Update documentation** if Railway.app infrastructure changes

### Annual Tasks (Once per year)
- [ ] **Security audit** of certificate pinning implementation
- [ ] **Review pinning vs. other security measures** effectiveness
- [ ] **Update monitoring and alerting systems**
- [ ] **Train team members** on certificate management procedures

---

## 🔧 Technical Procedures

### Extract New Certificate Hashes
```swift
// In development build, add this to a debug menu or startup:
#if DEBUG
CertificateHashExtractor.extractRailwayHashes()
#endif
```

### Update Certificate Hashes
1. **Update CertificatePinner.swift:**
```swift
private var pinnedPublicKeyHashes: [String: Set<String>] = [
    "backend-production-cfbe.up.railway.app": [
        "sha256/[NEW_HASH_1]", // New primary certificate
        "sha256/[NEW_HASH_2]"  // New backup certificate
    ]
]
```

2. **Test the changes:**
```bash
xcodebuild -project Derrite.xcodeproj -scheme Derrite -destination 'platform=iOS Simulator,name=iPhone 16' build
```

3. **Deploy to production**

### Monitor Certificate Health
- **Check OSLog entries:**
  - Look for `certificate-pinning` category logs
  - Monitor for "validation failed" messages
  - Track failure counts and automatic fallback triggers

---

## 🛡️ Security Best Practices

### Certificate Management
- [ ] **Never hardcode placeholder hashes** in production builds
- [ ] **Always include backup certificates** to handle overlapping rotations
- [ ] **Test certificate extraction** in development before each update
- [ ] **Keep fallback mode enabled** to prevent app breakage during transitions

### Monitoring and Alerting
- [ ] **Set up monitoring** for certificate expiration dates
- [ ] **Monitor app connectivity metrics** for pinning-related failures  
- [ ] **Track user-reported connection issues** that might indicate pinning problems
- [ ] **Log security events** but avoid logging sensitive information

### Team Coordination
- [ ] **Document all certificate changes** in version control
- [ ] **Coordinate updates** between iOS and Android teams
- [ ] **Test on both platforms** before releasing updates
- [ ] **Have rollback plans** ready for emergency scenarios

---

## 📊 Monitoring Metrics

### Key Performance Indicators
- **Certificate validation success rate** (should be >99%)
- **Fallback mode activation frequency** (should be rare)
- **User-reported connection issues** (track spikes after updates)
- **App store review sentiment** (watch for connectivity complaints)

### Security Metrics  
- **Failed pinning attempts** (could indicate attacks)
- **Certificate rotation frequency** (Railway.app baseline)
- **Time to recovery** when rotation occurs
- **Cross-platform deployment coordination** effectiveness

---

## 🆘 Troubleshooting Common Issues

### App Won't Connect After Update
1. Check if Railway.app rotated certificates unexpectedly
2. Verify certificate hashes are correctly formatted (sha256/[base64])
3. Confirm fallback mode is enabled in CertificatePinner
4. Test with network debugging tools to see SSL handshake

### Users Report Connection Problems
1. Check app store reviews for patterns
2. Monitor social media for connectivity reports
3. Review server-side logs for SSL failures
4. Consider emergency update with relaxed pinning

### Development Tool Not Working
1. Verify network connectivity to Railway.app backend
2. Check iOS simulator network permissions
3. Confirm CertificateHashExtractor import statements
4. Test with real device if simulator fails

---

## 📞 Emergency Contacts

### Internal Team
- **iOS Developer:** [Your Contact]
- **Android Developer:** [Your Contact]  
- **Backend/DevOps:** [Your Contact]
- **Release Manager:** [Your Contact]

### External Services
- **Railway.app Support:** [Check Railway.app documentation]
- **App Store Expedited Review:** [Apple Developer Portal]
- **Google Play Emergency Publishing:** [Google Play Console]

---

## 📝 Change Log Template

### Certificate Update - [Date]
- **Reason:** [Scheduled rotation / Emergency / Security incident]
- **Old Hashes:** [List removed hashes]
- **New Hashes:** [List new hashes]
- **Apps Updated:** [iOS version / Android version]
- **Deployment Date:** [When released to stores]
- **Issues Encountered:** [Any problems during update]
- **Resolution Time:** [How long process took]

---

## ✅ Post-Update Verification

After each certificate update:
- [ ] **iOS app connects successfully** to Railway.app backend
- [ ] **Android app connects successfully** (coordinate with Android team)
- [ ] **No user reports** of connection issues 24 hours after release
- [ ] **App store ratings** remain stable (no spike in 1-star reviews)
- [ ] **Backend logs** show normal SSL handshake patterns
- [ ] **Monitoring dashboards** show healthy connectivity metrics

---

*This checklist should be reviewed and updated whenever the certificate pinning implementation changes or Railway.app infrastructure evolves.*