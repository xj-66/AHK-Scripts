/*
    配置工具类
    提供配置文件的加载、保存和创建功能
    与业务无关的通用配置操作
*/

class ConfigUtils {

    /*
        创建默认配置文件
        @param configPath 配置文件路径
        @param defaultConfig 默认配置对象，格式为 {section: {key: defaultValue}}
    */
    static CreateDefault(configPath, defaultConfig) {
        for section, keys in defaultConfig.OwnProps() {
            for key, defaultValue in keys.OwnProps() {
                IniWrite(defaultValue, configPath, section, key)
            }
        }
    }
    
    /*
        加载配置文件
        @param configPath 配置文件路径
        @param configStructure 配置结构定义对象，格式为 {section: {key: defaultValue}}
        @return 包含配置值的对象
    */
    static Load(configPath, configStructure) {
        configObj := {}
        for section, keys in configStructure.OwnProps() {
            configObj.%section% := {}
            for key, defaultValue in keys.OwnProps() {
                value := IniRead(configPath, section, key, defaultValue)
                configObj.%section%.%key% := value
            }
        }
        return configObj
    }
    
    /*
        保存配置到文件
        @param configPath 配置文件路径
        @param configData 配置数据对象，格式为 {section: {key: value}}
    */
    static Save(configPath, configData) {
        for section, keys in configData.OwnProps() {
            for key, value in keys.OwnProps() {
                IniWrite(value, configPath, section, key)
            }
        }
    }
}